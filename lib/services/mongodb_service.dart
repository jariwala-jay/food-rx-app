import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';

class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  factory MongoDBService() => _instance;
  MongoDBService._internal();

  late Db _db;
  Db get db => _db;
  late DbCollection _usersCollection;
  late DbCollection _dietPlansCollection;
  late DbCollection _educationalContentCollection;
  late GridFS _profilePhotosBucket;

  // Make collections accessible
  DbCollection get usersCollection => _usersCollection;
  DbCollection get dietPlansCollection => _dietPlansCollection;
  DbCollection get educationalContentCollection =>
      _educationalContentCollection;
  GridFS get profilePhotosBucket => _profilePhotosBucket;

  // Security constants
  static const int _saltLength = 32;
  static const int _iterations = 10000;
  static const int _keyLength = 32;

  Future<void> initialize() async {
    await dotenv.load();
    final connectionString = dotenv.env['MONGODB_URL'];
    if (connectionString == null) {
      throw Exception('MONGODB_URL not found in .env file');
    }

    _db = await Db.create(connectionString);
    await _db.open();

    _usersCollection = _db.collection('users');
    _dietPlansCollection = _db.collection('diet_plans');
    _educationalContentCollection = _db.collection('educational_content');
    _profilePhotosBucket = GridFS(_db, 'profile_photos');

    await _usersCollection.createIndex(keys: {'email': 1}, unique: true);
  }

  String _hashPassword(String password) {
    try {
      // Generate a random salt
      final random = Random.secure();
      final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
      final saltBase64 = base64.encode(salt);

      // Hash the password with the salt
      final key = utf8.encode(password);
      final hmac = Hmac(sha256, key);
      final hash = hmac.convert(salt).toString();

      // Store salt and hash together
      final result = '$saltBase64:$hash';
      print('Password hashing details:');
      print('Salt: $saltBase64');
      print('Hash: $hash');
      print('Final stored value: $result');
      return result;
    } catch (e) {
      print('Error in _hashPassword: $e');
      rethrow;
    }
  }

  bool _verifyPassword(String password, String storedHash) {
    try {
      print('Password verification details:');
      print('Stored hash: $storedHash');

      // Check if the stored hash is in the correct format
      if (!storedHash.contains(':')) {
        print('ERROR: Password was stored in plain text!');
        // For existing users with plain text passwords, hash it now
        final hashedPassword = _hashPassword(storedHash);
        // Update the user's password in the database
        _updateUserPassword(storedHash, hashedPassword);
        return false;
      }

      final parts = storedHash.split(':');
      if (parts.length != 2) {
        print('Invalid hash format: $storedHash');
        return false;
      }

      // Extract salt and stored hash
      final salt = base64.decode(parts[0]);
      final storedKey = parts[1];
      print('Extracted salt: ${base64.encode(salt)}');
      print('Stored key: $storedKey');

      // Hash the provided password with the stored salt
      final key = utf8.encode(password);
      final hmac = Hmac(sha256, key);
      final computedHash = hmac.convert(salt).toString();
      print('Computed hash: $computedHash');

      // Compare the computed hash with the stored hash
      final result = storedKey == computedHash;
      print('Verification result: $result');
      return result;
    } catch (e) {
      print('Error in _verifyPassword: $e');
      return false;
    }
  }

  Future<void> _updateUserPassword(
      String email, String newHashedPassword) async {
    try {
      await _usersCollection.updateOne(
        {'email': email},
        {
          '\$set': {
            'password': newHashedPassword,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        },
      );
      print('Updated password hash for user: $email');
    } catch (e) {
      print('Error updating password hash: $e');
    }
  }

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    return await _usersCollection.findOne({'email': email});
  }

  Future<Map<String, dynamic>?> findUserById(String id) async {
    try {
      if (id.length != 24) {
        print('Invalid ObjectId format: $id');
        return null;
      }
      return await _usersCollection
          .findOne({'_id': ObjectId.fromHexString(id)});
    } catch (e) {
      print('Error finding user by ID: $e');
      return null;
    }
  }

  Future<bool> registerUser({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
    File? profilePhoto,
  }) async {
    try {
      if (await findUserByEmail(email) != null) {
        return false;
      }

      // Hash the password before storing
      final hashedPassword = _hashPassword(password);
      print('Password hashing debug:');
      print('Original password: $password');
      print('Hashed password: $hashedPassword');

      String? profilePhotoId;

      if (profilePhoto != null) {
        profilePhotoId = await uploadProfilePhoto(profilePhoto);
      }

      final userId = ObjectId();
      final userDocument = {
        '_id': userId,
        'email': email,
        'password': hashedPassword, // Use the hashed password here
        ...userData,
        'profilePhotoId': profilePhotoId,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'lastLoginAt': null,
        'failedLoginAttempts': 0,
        'isLocked': false,
        'lockUntil': null,
      };

      print('User document before insertion:');
      print(userDocument);

      // Verify the password was hashed before storing
      if (userDocument['password'] == password) {
        throw Exception('Password was not hashed before storage!');
      }

      await _usersCollection.insertOne(userDocument);
      await _storeSession(userId.toHexString(), email);
      return true;
    } catch (e) {
      print('Error registering user: $e');
      return false;
    }
  }

  Future<bool> loginUser(String email, String password) async {
    try {
      final user = await findUserByEmail(email);
      if (user == null) return false;

      print('Login debug:');
      print('Stored password hash: ${user['password']}');
      print('Attempting to verify password...');

      if (user['isLocked'] == true) {
        final lockUntil = user['lockUntil'];
        if (lockUntil != null &&
            DateTime.parse(lockUntil).isAfter(DateTime.now())) {
          return false;
        }
      }

      // Verify the password using the stored hash
      final isPasswordValid = _verifyPassword(password, user['password']);
      print('Password verification result: $isPasswordValid');

      if (!isPasswordValid) {
        await _handleFailedLogin(user['_id']);
        return false;
      }

      await _handleSuccessfulLogin(user['_id']);
      final objectId = user['_id'] as ObjectId;
      await _storeSession(objectId.toHexString(), email);
      return true;
    } catch (e) {
      print('Error logging in: $e');
      return false;
    }
  }

  Future<void> _handleFailedLogin(ObjectId userId) async {
    await _usersCollection.updateOne(
      {'_id': userId},
      {
        '\$inc': {'failedLoginAttempts': 1},
        '\$set': {'updatedAt': DateTime.now().toIso8601String()},
      },
    );

    final user = await _usersCollection.findOne({'_id': userId});
    if (user != null && user['failedLoginAttempts'] >= 5) {
      await _usersCollection.updateOne(
        {'_id': userId},
        {
          '\$set': {
            'isLocked': true,
            'lockUntil': DateTime.now()
                .add(const Duration(minutes: 30))
                .toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        },
      );
    }
  }

  Future<void> _handleSuccessfulLogin(ObjectId userId) async {
    await _usersCollection.updateOne(
      {'_id': userId},
      {
        '\$set': {
          'failedLoginAttempts': 0,
          'isLocked': false,
          'lockUntil': null,
          'lastLoginAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      },
    );
  }

  Future<void> _storeSession(String userId, String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Ensure we're storing a valid hex string
      String validUserId = userId;
      if (userId.contains('ObjectId')) {
        // Extract hexString from ObjectId("hexString") format
        validUserId = userId.replaceAll(RegExp(r'[^a-fA-F0-9]'), '');
      }

      if (validUserId.length != 24) {
        print(
            'Warning: Storing potentially invalid ObjectId: $userId -> $validUserId');
      }

      await prefs.setString('user_id', validUserId);
      await prefs.setString('user_email', email);
    } catch (e) {
      print('Error storing session: $e');
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
  }

  Future<String?> uploadProfilePhoto(File photo) async {
    try {
      final photoBytes = await photo.readAsBytes();
      final photoId = ObjectId();

      await _profilePhotosBucket.files.insertOne({
        '_id': photoId,
        'filename': 'profile_photo_${photoId.toHexString()}.jpg',
        'contentType': 'image/jpeg',
        'length': photoBytes.length,
        'uploadDate': DateTime.now().toIso8601String(),
      });

      await _profilePhotosBucket.chunks.insertOne({
        'files_id': photoId,
        'n': 0,
        'data': photoBytes,
      });

      return photoId.toHexString();
    } catch (e) {
      print('Error uploading profile photo: $e');
      return null;
    }
  }

  Future<List<int>?> getProfilePhoto(String photoId) async {
    try {
      final file = await _profilePhotosBucket.files
          .findOne({'_id': ObjectId.fromHexString(photoId)});
      if (file == null) return null;

      final chunk = await _profilePhotosBucket.chunks
          .findOne({'files_id': ObjectId.fromHexString(photoId)});
      if (chunk == null) return null;

      return chunk['data'] as List<int>;
    } catch (e) {
      print('Error getting profile photo: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    await _usersCollection.updateOne(
      {'_id': ObjectId.fromHexString(userId)},
      {
        '\$set': {
          ...updates,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      },
    );
  }

  Future<void> close() async {
    await _db.close();
  }
}

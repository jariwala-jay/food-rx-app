import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';

class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  factory MongoDBService() => _instance;
  MongoDBService._internal();

  late Db _db;
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

  // Replace with your MongoDB Atlas connection string
  final String _connectionString =
      'mongodb+srv://jayjariwala017:Nu3TMPRbTPrWwrLQ@foodrx.ihb5dqh.mongodb.net/';
  final String _dbName = 'food_rx_db';

  // Security constants
  static const int _saltLength = 32;
  static const int _iterations = 10000;
  static const int _keyLength = 32;

  Future<void> initialize() async {
    _db = await Db.create(_connectionString);
    await _db.open();

    _usersCollection = _db.collection('users');
    _dietPlansCollection = _db.collection('diet_plans');
    _educationalContentCollection = _db.collection('educational_content');
    _profilePhotosBucket = GridFS(_db, 'profile_photos');

    // Create indexes for better performance and security
    await _usersCollection.createIndex(keys: {'email': 1}, unique: true);
    await _usersCollection.createIndex(keys: {'createdAt': 1});
  }

  // Enhanced password hashing with salt and PBKDF2
  String _hashPassword(String password) {
    final salt = List<int>.generate(_saltLength, (i) => i);
    final key = utf8.encode(password);
    final hmac = Hmac(sha256, key);
    final hash = hmac.convert(salt).toString();
    final saltBase64 = base64.encode(salt);
    return '$saltBase64:$hash';
  }

  bool _verifyPassword(String password, String storedHash) {
    try {
      final parts = storedHash.split(':');
      if (parts.length != 2) return false;

      final salt = base64.decode(parts[0]);
      final storedKey = parts[1];

      final key = utf8.encode(password);
      final hmac = Hmac(sha256, key);
      final computedHash = hmac.convert(salt).toString();

      return storedKey == computedHash;
    } catch (e) {
      print('Error verifying password: $e');
      return false;
    }
  }

  // User Authentication Methods
  Future<bool> registerUser({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
    File? profilePhoto,
  }) async {
    try {
      // Check if user already exists
      final existingUser = await _usersCollection.findOne({'email': email});
      if (existingUser != null) {
        print('User already exists');
        return false;
      }

      // Hash password with enhanced security
      final hashedPassword = _hashPassword(password);
      print('Password hashed successfully');

      // Handle profile photo upload if provided
      String? profilePhotoId;
      if (profilePhoto != null) {
        final photoBytes = await profilePhoto.readAsBytes();
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

        profilePhotoId = photoId.toHexString();
      }

      // Create a copy of userData without the password
      final userDataCopy = Map<String, dynamic>.from(userData);
      userDataCopy.remove('password');

      // Create user document with enhanced security
      final userDocument = {
        '_id': ObjectId(),
        'email': email,
        'password': hashedPassword, // Store the hashed password
        ...userDataCopy, // Use the copy without password
        'profilePhotoId': profilePhotoId,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'lastLoginAt': null,
        'failedLoginAttempts': 0,
        'isLocked': false,
        'lockUntil': null,
      };

      await _usersCollection.insertOne(userDocument);
      print('User document inserted successfully');

      // Store user session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userDocument['_id'].toString());
      await prefs.setString('user_email', email);
      print('User session stored successfully');

      return true;
    } catch (e) {
      print('Error registering user: $e');
      return false;
    }
  }

  Future<bool> loginUser(String email, String password) async {
    try {
      print('Attempting to login user: $email');
      final user = await _usersCollection.findOne({'email': email});
      if (user == null) {
        print('User not found');
        return false;
      }

      // Check if account is locked
      if (user['isLocked'] == true) {
        final lockUntil = user['lockUntil'];
        if (lockUntil != null &&
            DateTime.parse(lockUntil).isAfter(DateTime.now())) {
          print('Account is locked');
          return false;
        }
      }

      // Verify password using the stored hash
      print('Verifying password...');
      final isValid = _verifyPassword(password, user['password']);
      if (!isValid) {
        print('Invalid password');
        // Increment failed login attempts
        await _usersCollection.updateOne(
          {'_id': user['_id']},
          {
            '\$inc': {'failedLoginAttempts': 1},
            '\$set': {'updatedAt': DateTime.now().toIso8601String()},
          },
        );

        // Lock account after 5 failed attempts
        if (user['failedLoginAttempts'] + 1 >= 5) {
          await _usersCollection.updateOne(
            {'_id': user['_id']},
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
        return false;
      }

      print('Password verified successfully');
      // Reset failed attempts and update last login
      await _usersCollection.updateOne(
        {'_id': user['_id']},
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

      // Store user session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user['_id'].toString());
      await prefs.setString('user_email', email);
      print('User session stored successfully');

      print('Login successful');
      return true;
    } catch (e) {
      print('Error logging in: $e');
      return false;
    }
  }

  Future<void> logoutUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
  }

  // Profile photo methods
  Future<String?> uploadProfilePhoto(String userId, File photo) async {
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

      await _usersCollection.updateOne(
        {'_id': ObjectId.fromHexString(userId)},
        {
          '\$set': {
            'profilePhotoId': photoId.toHexString(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        },
      );

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

  // Diet Plan Methods
  Future<void> saveUserDietPlan(
      String userId, Map<String, dynamic> dietPlan) async {
    await _dietPlansCollection.insertOne({
      'userId': userId,
      ...dietPlan,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getUserDietPlan(String userId) async {
    return await _dietPlansCollection.findOne({'userId': userId});
  }

  // Educational Content Methods
  Future<List<Map<String, dynamic>>> getEducationalContent(
      String userId) async {
    final user =
        await _usersCollection.findOne({'_id': ObjectId.fromHexString(userId)});
    if (user == null) return [];

    // Get content based on user's diet type and preferences
    final content = await _educationalContentCollection.find({
      'dietType': user['dietType'],
      'preferences': {'\$in': user['preferences']},
    }).toList();

    return content;
  }

  Future<void> close() async {
    await _db.close();
  }
}

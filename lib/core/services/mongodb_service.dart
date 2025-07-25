import 'dart:async';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import 'package:flutter_app/core/utils/objectid_helper.dart';

class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  factory MongoDBService() => _instance;
  MongoDBService._internal();

  late Db _db;
  Db get db => _db;
  late DbCollection _usersCollection;
  late DbCollection _dietPlansCollection;
  late DbCollection _educationalContentCollection;
  late DbCollection _pantryCollection;
  late GridFS _profilePhotosBucket;
  bool _isInitialized = false;

  // Make collections accessible
  DbCollection get usersCollection => _usersCollection;
  DbCollection get dietPlansCollection => _dietPlansCollection;
  DbCollection get educationalContentCollection =>
      _educationalContentCollection;
  DbCollection get pantryCollection => _pantryCollection;
  GridFS get profilePhotosBucket => _profilePhotosBucket;

  // Security constants
  static const int _saltLength = 32;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await dotenv.load();
    final connectionString = dotenv.env['MONGODB_URL'];
    if (connectionString == null) {
      throw Exception('MONGODB_URL not found in .env file');
    }

    Db localDb;
    try {
      localDb = await Db.create(connectionString);
      await localDb.open().timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException(
            'MongoDB connection timed out during initialize (10 seconds)');
      });
      // Optionally, verify connection here too
      // final serverStatus = await localDb.serverStatus();
      // if (serverStatus == null || serverStatus['ok'] != 1.0) {
      //   throw Exception("MongoDB server status check failed during initial connect.");
      // }
    } catch (e) {
      print("Error during MongoDB initial connection: $e");
      _isInitialized = false; // Ensure it's false if init fails
      rethrow; // Propagate the error
    }

    _db = localDb; // Assign only after successful open

    _usersCollection = _db.collection('users');
    _dietPlansCollection = _db.collection('diet_plans');
    _educationalContentCollection = _db.collection('educational_content');
    _pantryCollection = _db.collection('pantry_items');
    _profilePhotosBucket = GridFS(_db, 'profile_photos');

    await _usersCollection.createIndex(keys: {'email': 1}, unique: true);
    await _pantryCollection.createIndex(keys: {'userId': 1});
    await _pantryCollection.createIndex(keys: {'expiryDate': 1});

    // Create index for bookmarkedBy field
    await _educationalContentCollection.createIndex(
      keys: {'bookmarkedBy': 1},
      sparse: true,
    );

    // Create indexes for tracker collection
    final trackersCollection = _db.collection('user_trackers');
    await trackersCollection.createIndex(keys: {'userId': 1});
    await trackersCollection.createIndex(keys: {'userId': 1, 'dietType': 1});
    await trackersCollection
        .createIndex(keys: {'userId': 1, 'isWeeklyGoal': 1});

    // Create indexes for tracker progress collection (for analytics)
    final progressCollection = _db.collection('tracker_progress');
    await progressCollection.createIndex(keys: {'userId': 1});
    await progressCollection.createIndex(keys: {'userId': 1, 'trackerId': 1});
    await progressCollection.createIndex(keys: {'userId': 1, 'periodType': 1});
    await progressCollection
        .createIndex(keys: {'userId': 1, 'progressDate': -1});
    await progressCollection.createIndex(keys: {'progressDate': -1});

    // Only set _isInitialized to true if all steps complete successfully
    _isInitialized = true;
  }

  Future<void> ensureConnection() async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        throw Exception('Failed to initialize MongoDB connection: $e');
      }
    }

    try {
      // Check connection status
      if (_db.state == State.CLOSED) {
        await _db.open().timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException(
              'MongoDB connection timed out during reopen (15 seconds)');
        });

        // Add a small delay to allow connection to stabilize
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Verify server status with a ping
      try {
        final pingResult = await _db.runCommand({'ping': 1}).timeout(
            const Duration(seconds: 5), onTimeout: () {
          throw TimeoutException('MongoDB ping check timed out (5 seconds)');
        });

        if (pingResult['ok'] != 1.0) {
          // If ping doesn't work, try server status as fallback
          final serverStatus =
              await _db.serverStatus().timeout(const Duration(seconds: 5));

          if (serverStatus['ok'] != 1.0) {
            throw Exception("MongoDB is not responding correctly");
          }
        }
      } catch (e) {
        // If ping fails, try to reopen the connection
        await _db.close();
        await initialize();
      }
    } catch (e) {
      _isInitialized = false;
      throw Exception('MongoDB connection failed: $e');
    }
  }

  Future<void> close() async {
    if (_isInitialized && _db.state != State.CLOSED) {
      await _db.close();
      _isInitialized = false;
    }
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
      return result;
    } catch (e) {
      rethrow;
    }
  }

  bool _verifyPassword(String password, String storedHash) {
    try {
      // Check if the stored hash is in the correct format
      if (!storedHash.contains(':')) {
        final hashedPassword = _hashPassword(storedHash);
        // Update the user's password in the database
        _updateUserPassword(storedHash, hashedPassword);
        return false;
      }

      final parts = storedHash.split(':');
      if (parts.length != 2) {
        return false;
      }

      // Extract salt and stored hash
      final salt = base64.decode(parts[0]);
      final storedKey = parts[1];

      // Hash the provided password with the stored salt
      final key = utf8.encode(password);
      final hmac = Hmac(sha256, key);
      final computedHash = hmac.convert(salt).toString();

      // Compare the computed hash with the stored hash
      final result = storedKey == computedHash;
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateUserPassword(
      String email, String newHashedPassword) async {
    try {
      await ensureConnection();
      await _usersCollection.updateOne(
        {'email': email},
        {
          '\$set': {
            'password': newHashedPassword,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        },
      );
    } catch (e) {
      throw Exception('Failed to update user password: $e');
    }
  }

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    try {
      await ensureConnection();
      return await _usersCollection.findOne({'email': email});
    } catch (e) {
      throw Exception('Failed to find user by email: $e');
    }
  }

  Future<Map<String, dynamic>?> findUserById(String id) async {
    try {
      await ensureConnection();
      if (id.length != 24) {
        return null;
      }
      return await _usersCollection
          .findOne({'_id': parseObjectId(id)});
    } catch (e) {
      throw Exception('Failed to find user by ID: $e');
    }
  }

  Future<bool> registerUser({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
    File? profilePhoto,
  }) async {
    try {
      await ensureConnection();
      if (await findUserByEmail(email) != null) {
        return false;
      }

      final hashedPassword = _hashPassword(password);
      String? profilePhotoId;

      if (profilePhoto != null) {
        profilePhotoId = await uploadProfilePhoto(profilePhoto);
      }

      final userId = ObjectId();
      final userDocument = {
        '_id': userId,
        'email': email,
        'password': hashedPassword,
        ...userData,
        'profilePhotoId': profilePhotoId,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'lastLoginAt': null,
        'failedLoginAttempts': 0,
        'isLocked': false,
        'lockUntil': null,
      };

      if (userDocument['password'] == password) {
        throw Exception('Password was not hashed before storage!');
      }

      await _usersCollection.insertOne(userDocument);
      await _storeSession(userId.toHexString(), email);
      return true;
    } catch (e) {
      throw Exception('Failed to register user: $e');
    }
  }

  Future<bool> loginUser(String email, String password) async {
    try {
      await ensureConnection();
      final user = await findUserByEmail(email);
      if (user == null) return false;

      if (user['isLocked'] == true) {
        final lockUntil = user['lockUntil'];
        if (lockUntil != null &&
            DateTime.parse(lockUntil).isAfter(DateTime.now())) {
          return false;
        }
      }

      final isPasswordValid = _verifyPassword(password, user['password']);

      if (!isPasswordValid) {
        await _handleFailedLogin(user['_id']);
        return false;
      }

      await _handleSuccessfulLogin(user['_id']);
      final objectId = user['_id'] as ObjectId;
      await _storeSession(objectId.toHexString(), email);
      return true;
    } catch (e) {
      throw Exception('Failed to login user: $e');
    }
  }

  Future<void> _handleFailedLogin(ObjectId userId) async {
    try {
      await ensureConnection();
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
    } catch (e) {
      throw Exception('Failed to handle failed login: $e');
    }
  }

  Future<void> _handleSuccessfulLogin(ObjectId userId) async {
    try {
      await ensureConnection();
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
    } catch (e) {
      throw Exception('Failed to handle successful login: $e');
    }
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

      await prefs.setString('user_id', validUserId);
      await prefs.setString('user_email', email);
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
  }

  Future<String?> uploadProfilePhoto(File photo) async {
    try {
      await ensureConnection();
      final photoBytes = await photo.readAsBytes();
      final photoId = ObjectId();

      final fileMetadata = {
        '_id': photoId,
        'filename': 'profile_photo_${photoId.toHexString()}.jpg',
        'contentType': 'image/jpeg',
        'length': photoBytes.length,
        'uploadDate': DateTime.now().toIso8601String(),
      };

      final fileResult =
          await _profilePhotosBucket.files.insertOne(fileMetadata);
      if (!fileResult.isSuccess) {
        throw Exception(
            'Failed to insert file metadata: ${fileResult.writeError?.errmsg}');
      }

      final chunkResult = await _profilePhotosBucket.chunks.insertOne({
        'files_id': photoId,
        'n': 0,
        'data': photoBytes,
      });

      if (!chunkResult.isSuccess) {
        await _profilePhotosBucket.files.deleteOne({'_id': photoId});
        throw Exception(
            'Failed to insert file chunk: ${chunkResult.writeError?.errmsg}');
      }

      final uploadedFile =
          await _profilePhotosBucket.files.findOne({'_id': photoId});
      if (uploadedFile == null) {
        throw Exception('Failed to verify file upload');
      }

      return photoId.toHexString();
    } catch (e) {
      throw Exception('Failed to upload profile photo: $e');
    }
  }

  Future<List<int>?> getProfilePhoto(String photoId) async {
    try {
      await ensureConnection();
      final objectId = parseObjectId(photoId);

      final file = await _profilePhotosBucket.files.findOne({'_id': objectId});
      if (file == null) {
        return null;
      }

      final chunk =
          await _profilePhotosBucket.chunks.findOne({'files_id': objectId});
      if (chunk == null) {
        return null;
      }

      final dynamicData = chunk['data'] as List<dynamic>;
      return dynamicData.map((e) => e as int).toList();
    } catch (e) {
      throw Exception('Failed to get profile photo: $e');
    }
  }

  // Add a method to get the profile photo URL
  String getProfilePhotoUrl(String photoId) {
    final connectionString = dotenv.env['MONGODB_URL'];
    if (connectionString == null) {
      throw Exception('MONGODB_URL not found in .env file');
    }

    // Extract the host from the MongoDB connection string
    final uri = Uri.parse(connectionString);
    final host = uri.host;

    // Construct the profile photo URL using https scheme
    return 'https://$host/api/profile-photos/$photoId';
  }

  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      await ensureConnection();
      await _usersCollection.updateOne(
        {'_id': parseObjectId(userId)},
        {
          '\$set': {
            ...updates,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        },
      );
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  Future<void> updateArticleBookmark(
      String articleId, bool isBookmarked, String userId) async {
    try {
      await ensureConnection();
      final articleObjectId = parseObjectId(articleId);
      final userObjectId = parseObjectId(userId);

      final article =
          await _educationalContentCollection.findOne({'_id': articleObjectId});
      if (article == null) {
        throw Exception('Article not found with ID: $articleId');
      }

      if (isBookmarked) {
        final result = await _educationalContentCollection.updateOne(
          {'_id': articleObjectId},
          {
            '\$addToSet': {'bookmarkedBy': userObjectId}
          },
        );
        if (!result.isSuccess) {
          throw Exception(
              'Failed to add bookmark: ${result.writeError?.errmsg}');
        }
      } else {
        final result = await _educationalContentCollection.updateOne(
          {'_id': articleObjectId},
          {
            '\$pull': {'bookmarkedBy': userObjectId}
          },
        );
        if (!result.isSuccess) {
          throw Exception(
              'Failed to remove bookmark: ${result.writeError?.errmsg}');
        }
      }

      final updatedArticle =
          await _educationalContentCollection.findOne({'_id': articleObjectId});
      if (updatedArticle == null) {
        throw Exception('Failed to verify bookmark update');
      }
    } catch (e) {
      throw Exception('Failed to update bookmark in MongoDB: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getBookmarkedArticles(
      String userId) async {
    try {
      await ensureConnection();
      final userObjectId = parseObjectId(userId);
      final articles = await _educationalContentCollection
          .find({'bookmarkedBy': userObjectId}).toList();
      return articles;
    } catch (e) {
      throw Exception('Failed to get bookmarked articles: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getArticles({
    String? category,
    String? userId,
    bool bookmarksOnly = false,
    String? search,
  }) async {
    try {
      await ensureConnection();
      final query = <String, dynamic>{};

      if (category != null && category != 'All' && !bookmarksOnly) {
        query['category'] = category;
      }

      if (bookmarksOnly && userId != null) {
        query['bookmarkedBy'] = parseObjectId(userId);
      }

      if (search != null && search.isNotEmpty) {
        query['\$text'] = {'\$search': search};
      }

      var articles = await _educationalContentCollection.find(query).toList();

      if (search != null && search.isNotEmpty) {
        articles.sort((a, b) {
          final scoreA = a['score'] ?? 0;
          final scoreB = b['score'] ?? 0;
          return scoreB.compareTo(scoreA);
        });
      }

      if (articles.isEmpty && category != null) {
        articles = await _educationalContentCollection.find().toList();
      }

      return articles;
    } catch (e) {
      throw Exception('Failed to get articles: $e');
    }
  }

  ObjectId parseObjectId(dynamic id) {
    // Use the robust ObjectIdHelper instead of custom parsing
    return ObjectIdHelper.parseObjectId(id);
  }

  // When serializing ObjectId to string, always use toHexString()
  // Example: String idString = objectId.toHexString();

  // When deserializing, always use parseObjectId() or ObjectId.fromHexString()

  // Pantry Item Methods
  Future<List<Map<String, dynamic>>> getPantryItems(String userId,
      {bool isPantryItem = true}) async {
    try {
      await ensureConnection();
      final userObjectId = parseObjectId(userId);
      final items = await _pantryCollection.find({
        'userId': userObjectId,
        'isPantryItem': isPantryItem,
      }).toList();
      return items;
    } catch (e) {
      throw Exception('Failed to get pantry items: $e');
    }
  }

  Future<String> addPantryItem(
      String userId, Map<String, dynamic> itemData) async {
    try {
      await ensureConnection();
      final userObjectId = parseObjectId(userId);
      final itemId = ObjectId();

      final itemDocument = {
        '_id': itemId,
        'userId': userObjectId,
        ...itemData,
        'addedDate': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _pantryCollection.insertOne(itemDocument);
      return itemId.toHexString();
    } catch (e) {
      throw Exception('Failed to add pantry item: $e');
    }
  }

  Future<void> updatePantryItem(
      dynamic id, Map<String, dynamic> updates) async {
    try {
      await ensureConnection();
      final objectId = parseObjectId(id);
      await _pantryCollection.updateOne(
        {'_id': objectId},
        {
          '\$set': {
            ...updates,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        },
      );
    } catch (e) {
      throw Exception('Failed to update pantry item: $e');
    }
  }

  Future<void> deletePantryItem(dynamic id) async {
    try {
      await ensureConnection();

      // Convert the ID to a valid ObjectId using the robust helper
      final objectId = parseObjectId(id);

      print(
          'Deleting pantry item with parsed ObjectId: ${objectId.toHexString()}');

      // Perform the deletion
      final result = await _pantryCollection.deleteOne({'_id': objectId});

      if (!result.isSuccess) {
        throw Exception(
            'Failed to delete pantry item: ${result.writeError?.errmsg}');
      }
    } catch (e) {
      throw Exception('Failed to delete pantry item: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getExpiringItems(String userId,
      {int daysThreshold = 7}) async {
    try {
      await ensureConnection();
      final userObjectId = parseObjectId(userId);
      final thresholdDate = DateTime.now().add(Duration(days: daysThreshold));

      final items = await _pantryCollection.find({
        'userId': userObjectId,
        'expiryDate': {
          '\$exists': true,
          '\$ne': null,
          '\$lte': thresholdDate.toIso8601String(),
        },
      }).toList();
      return items;
    } catch (e) {
      throw Exception('Failed to get expiring items: $e');
    }
  }
}

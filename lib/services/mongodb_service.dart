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

    // Create index for bookmarkedBy field
    await _educationalContentCollection.createIndex(
      keys: {'bookmarkedBy': 1},
      sparse: true,
    );
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
      throw Exception(e);
    }
  }

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    return await _usersCollection.findOne({'email': email});
  }

  Future<Map<String, dynamic>?> findUserById(String id) async {
    try {
      if (id.length != 24) {
        return null;
      }
      return await _usersCollection
          .findOne({'_id': ObjectId.fromHexString(id)});
    } catch (e) {
      throw Exception(e);
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

      // Verify the password was hashed before storing
      if (userDocument['password'] == password) {
        throw Exception('Password was not hashed before storage!');
      }

      await _usersCollection.insertOne(userDocument);
      await _storeSession(userId.toHexString(), email);
      return true;
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<bool> loginUser(String email, String password) async {
    try {
      final user = await findUserByEmail(email);
      if (user == null) return false;

      if (user['isLocked'] == true) {
        final lockUntil = user['lockUntil'];
        if (lockUntil != null &&
            DateTime.parse(lockUntil).isAfter(DateTime.now())) {
          return false;
        }
      }

      // Verify the password using the stored hash
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
      throw Exception(e);
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
      final photoBytes = await photo.readAsBytes();

      final photoId = ObjectId();

      // Create file metadata
      final fileMetadata = {
        '_id': photoId,
        'filename': 'profile_photo_${photoId.toHexString()}.jpg',
        'contentType': 'image/jpeg',
        'length': photoBytes.length,
        'uploadDate': DateTime.now().toIso8601String(),
      };

      // Insert file metadata
      final fileResult =
          await _profilePhotosBucket.files.insertOne(fileMetadata);

      if (!fileResult.isSuccess) {
        throw Exception(
            'Failed to insert file metadata: ${fileResult.writeError?.errmsg}');
      }

      // Insert file data
      final chunkResult = await _profilePhotosBucket.chunks.insertOne({
        'files_id': photoId,
        'n': 0,
        'data': photoBytes,
      });

      if (!chunkResult.isSuccess) {
        // Clean up file metadata if chunk insert fails
        await _profilePhotosBucket.files.deleteOne({'_id': photoId});
        throw Exception(
            'Failed to insert file chunk: ${chunkResult.writeError?.errmsg}');
      }

      // Verify the upload
      final uploadedFile =
          await _profilePhotosBucket.files.findOne({'_id': photoId});
      if (uploadedFile == null) {
        throw Exception('Failed to verify file upload');
      }

      // Return the photo ID as a hex string
      return photoId.toHexString();
    } catch (e) {
      throw Exception('Failed to upload profile photo: $e');
    }
  }

  Future<List<int>?> getProfilePhoto(String photoId) async {
    try {
      // Convert string ID to ObjectId
      final objectId = ObjectId.fromHexString(photoId);

      // Get file metadata
      final file = await _profilePhotosBucket.files.findOne({'_id': objectId});
      if (file == null) {
        return null;
      }

      // Get file data
      final chunk =
          await _profilePhotosBucket.chunks.findOne({'files_id': objectId});
      if (chunk == null) {
        return null;
      }

      // Convert dynamic list to List<int>
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

  Future<void> updateArticleBookmark(
      String articleId, bool isBookmarked, String userId) async {
    try {
      // Convert string IDs to ObjectId
      final articleObjectId = ObjectId.fromHexString(articleId);
      final userObjectId = ObjectId.fromHexString(userId);

      // Verify article exists
      final article =
          await _educationalContentCollection.findOne({'_id': articleObjectId});
      if (article == null) {
        throw Exception('Article not found with ID: $articleId');
      }

      if (isBookmarked) {
        // Add bookmark
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
        // Remove bookmark
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

      // Verify the update
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
      final userObjectId = ObjectId.fromHexString(userId);
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
      final query = <String, dynamic>{};

      if (category != null && category != 'All' && !bookmarksOnly) {
        query['category'] = category;
      }

      // If bookmarksOnly is true, only fetch bookmarked articles
      if (bookmarksOnly && userId != null) {
        query['bookmarkedBy'] = ObjectId.fromHexString(userId);
      }

      // Add text search if search query is provided
      if (search != null && search.isNotEmpty) {
        query['\$text'] = {'\$search': search};
      }

      // Get all articles matching the category and search
      var articles = await _educationalContentCollection.find(query).toList();

      // Sort by text score if search is provided
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
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../services/mongodb_service.dart';
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart';

class AuthProvider with ChangeNotifier {
  final MongoDBService _mongoDBService = MongoDBService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  static const String _dbUrl =
      'mongodb+srv://jayjariwala017:Nu3TMPRbTPrWwrLQ>@foodrx.ihb5dqh.mongodb.net/';
  static const String _usersCollection = 'users';
  static const String _profilePhotosCollection = 'profile_photos';

  Db? _db;
  DbCollection? _users;
  DbCollection? _profilePhotos;
  String? _profilePhotoId;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  UserModel get data => _currentUser ?? UserModel(email: '');

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _mongoDBService.initialize();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final userEmail = prefs.getString('user_email');

      if (userId != null && userEmail != null) {
        print('Found stored session - User ID: $userId');
        // Extract the actual ID from the ObjectId string
        final idMatch = RegExp(r'ObjectId\("([^"]+)"\)').firstMatch(userId);
        final actualId = idMatch?.group(1) ?? userId;

        // Fetch user data from MongoDB
        final userData = await _mongoDBService.usersCollection.findOne({
          '_id': ObjectId.fromHexString(actualId),
          'email': userEmail,
        });

        if (userData != null) {
          print('Loading user data from MongoDB');
          _currentUser = UserModel.fromJson(userData);
          print('Current user set - ID: ${_currentUser!.id}');
        } else {
          print('No user data found in MongoDB');
          // Clear invalid session
          await prefs.remove('user_id');
          await prefs.remove('user_email');
        }
      } else {
        print('No stored session found');
      }
    } catch (e) {
      print('Error initializing auth: $e');
      _error = 'Failed to initialize authentication: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
    File? profilePhoto,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First check if user exists
      final existingUser =
          await _mongoDBService.usersCollection.findOne({'email': email});
      if (existingUser != null) {
        _error = 'Email already exists';
        return false;
      }

      // Register the user
      final success = await _mongoDBService.registerUser(
        email: email,
        password: password,
        userData: userData,
        profilePhoto: profilePhoto,
      );

      if (success) {
        // Auto-login after successful registration
        final loginSuccess = await login(email, password);
        if (loginSuccess) {
          return true;
        }
        _error = 'Registration successful but login failed';
        return false;
      } else {
        _error = 'Registration failed';
        return false;
      }
    } catch (e) {
      _error = 'Registration failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('Attempting login for email: $email');
      final success = await _mongoDBService.loginUser(email, password);
      print('MongoDB login result: $success');

      if (success) {
        // Get the user data from MongoDB
        final userData =
            await _mongoDBService.usersCollection.findOne({'email': email});
        if (userData != null) {
          print('Creating user model from data');
          // Create user model and set it
          _currentUser = UserModel.fromJson(userData);
          print('Current user set - ID: ${_currentUser!.id}');

          // Store user session - store just the hex string of the ID
          final prefs = await SharedPreferences.getInstance();
          final userId = _currentUser!.id!
              .replaceAll('ObjectId("', '')
              .replaceAll('")', '');
          await prefs.setString('user_id', userId);
          await prefs.setString('user_email', _currentUser!.email);
          print('Session stored in SharedPreferences');

          // Force a state update
          _isLoading = false;
          notifyListeners();
          print('Auth state updated - isAuthenticated: true');
          return true;
        } else {
          print('User data not found in MongoDB');
          _error = 'User data not found';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        print('Invalid email or password');
        _error = 'Invalid email or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Login error: $e');
      _error = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Clear MongoDB session
      await _mongoDBService.logoutUser();

      // Clear local state
      _currentUser = null;

      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_email');

      print('Logout successful - User session cleared');
    } catch (e) {
      print('Error during logout: $e');
      _error = 'Logout failed: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (_currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _mongoDBService.usersCollection.updateOne(
        {'_id': ObjectId.fromHexString(_currentUser!.id!)},
        {
          '\$set': {
            ...updates,
            'updatedAt': DateTime.now(),
          },
        },
      );

      final updatedUser = await _mongoDBService.usersCollection.findOne({
        '_id': ObjectId.fromHexString(_currentUser!.id!),
      });

      if (updatedUser != null) {
        _currentUser = UserModel.fromJson(updatedUser);
      }
    } catch (e) {
      _error = 'Failed to update profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initDb() async {
    if (_db == null) {
      _db = await Db.create(_dbUrl);
      await _db!.open();
      _users = _db!.collection(_usersCollection);
      _profilePhotos = _db!.collection(_profilePhotosCollection);
    }
  }

  Future<void> updateProfilePhoto(File photo) async {
    if (_currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final photoId =
          await _mongoDBService.uploadProfilePhoto(_currentUser!.id!, photo);
      if (photoId != null) {
        _currentUser = _currentUser!.copyWith(profilePhotoId: photoId);
      }
    } catch (e) {
      _error = 'Failed to update profile photo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<int>?> getProfilePhoto() async {
    if (_currentUser?.profilePhotoId == null) return null;

    try {
      return await _mongoDBService
          .getProfilePhoto(_currentUser!.profilePhotoId!);
    } catch (e) {
      _error = 'Failed to get profile photo: $e';
      return null;
    }
  }
}

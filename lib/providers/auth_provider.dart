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

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _mongoDBService.initialize();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final userEmail = prefs.getString('user_email');

      if (userId != null && userEmail != null) {
        try {
          // Validate the user ID format before using it
          if (userId.length != 24) {
            await _mongoDBService.clearSession();
            throw Exception('Invalid user ID format');
          }

          final userData = await _mongoDBService.findUserById(userId);
          if (userData != null && userData['email'] == userEmail) {
            _currentUser = _createUserModel(userData);
          } else {
            await _mongoDBService.clearSession();
          }
        } catch (e) {
          await _mongoDBService.clearSession();
        }
      }
    } catch (e) {
      _error = 'Failed to initialize authentication: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  UserModel _createUserModel(Map<String, dynamic> userData) {
    // Convert ObjectId to String for the id field
    final id = userData['_id'] is ObjectId
        ? (userData['_id'] as ObjectId).toHexString()
        : userData['_id'].toString();

    return UserModel.fromJson({
      ...userData,
      '_id': id,
    });
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
      // Remove password from userData if it exists
      final cleanUserData = Map<String, dynamic>.from(userData);
      cleanUserData.remove('password');

      final success = await _mongoDBService.registerUser(
        email: email,
        password: password,
        userData: cleanUserData,
        profilePhoto: profilePhoto,
      );

      if (success) {
        return await login(email, password);
      }
      _error = 'Registration failed';
      return false;
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
      final success = await _mongoDBService.loginUser(email, password);
      if (success) {
        final userData = await _mongoDBService.findUserByEmail(email);
        if (userData != null) {
          _currentUser = _createUserModel(userData);
          return true;
        }
      }
      _error = 'Invalid email or password';
      return false;
    } catch (e) {
      _error = 'Login failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _mongoDBService.clearSession();
      _currentUser = null;
    } catch (e) {
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
      await _mongoDBService.updateUserProfile(_currentUser!.id!, updates);
      final updatedUser = await _mongoDBService.findUserById(_currentUser!.id!);
      if (updatedUser != null) {
        _currentUser = _createUserModel(updatedUser);
      }
    } catch (e) {
      _error = 'Failed to update profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfilePhoto(File photo) async {
    if (_currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final photoId = await _mongoDBService.uploadProfilePhoto(photo);
      if (photoId != null) {
        await _mongoDBService.updateUserProfile(_currentUser!.id!, {
          'profilePhotoId': photoId,
        });
        final updatedUser =
            await _mongoDBService.findUserById(_currentUser!.id!);
        if (updatedUser != null) {
          _currentUser = _createUserModel(updatedUser);
        }
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

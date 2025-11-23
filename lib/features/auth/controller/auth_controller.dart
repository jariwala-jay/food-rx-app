import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/services/nutrition_content_loader.dart';
import 'package:flutter_app/core/services/personalization_service.dart';
import 'package:flutter_app/core/services/replan_service.dart';
import 'package:flutter_app/core/services/notification_manager.dart';
import 'package:flutter_app/core/services/notification_service.dart';
import 'package:flutter_app/core/services/email_service.dart';
import 'package:flutter_app/core/services/gmail_smtp_email_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';

class AuthController with ChangeNotifier {
  final MongoDBService _mongoDBService = MongoDBService();
  final EmailService _emailService = GmailSMTPEmailService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  ReplanService? _replanService;
  ReplanTrigger? _pendingReplanTrigger;
  NotificationManager? _notificationManager;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  ReplanTrigger? get pendingReplanTrigger => _pendingReplanTrigger;
  NotificationManager? get notificationManager => _notificationManager;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _mongoDBService.initialize();

      // Initialize re-plan service
      try {
        final nutritionContent = await NutritionContentLoader.load();
        final personalizationService = PersonalizationService(nutritionContent);
        _replanService = ReplanService(personalizationService);
      } catch (e) {
        print('Warning: Failed to initialize re-plan service: $e');
      }

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

            // Initialize notification services
            await _initializeNotificationServices(_currentUser!.id!);
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
    // Use robust ObjectId handling for ID conversion
    final id = userData['_id'] != null
        ? ObjectIdHelper.toHexString(userData['_id'])
        : ObjectIdHelper.generateNew().toHexString();

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

  Future<bool> checkEmailExists(String email) async {
    try {
      final user = await _mongoDBService.findUserByEmail(email);
      return user != null;
    } catch (e) {
      // If there's an error checking, assume email doesn't exist to allow signup
      return false;
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

          // Initialize notification services (don't fail login if this fails)
          try {
            await _initializeNotificationServices(_currentUser!.id!);
          } catch (e) {
            // Log error but don't fail login
            debugPrint(
                'Warning: Failed to initialize notification services: $e');
            // Login should still succeed even if notifications fail
          }

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

      // Clean up notification services
      _notificationManager?.dispose();
      _notificationManager = null;

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
        final oldUser = _currentUser!;
        _currentUser = _createUserModel(updatedUser);

        // Check for re-plan triggers
        if (_replanService != null) {
          final trigger =
              await _replanService!.checkReplanTriggers(oldUser, _currentUser!);
          if (trigger != null) {
            // Automatically regenerate diet plan for all trigger types
            // This includes: condition_change, weight_change, height_change, dob_change, activity_change
            try {
              // Ensure weight is in pounds for personalization service
              final userForReplan = _currentUser!;
              double? weightLb = userForReplan.weight;
              if (weightLb != null && userForReplan.weightUnit == 'kg') {
                weightLb = weightLb * 2.205; // Convert kg to lbs
              }

              // Create a temporary user with weight in lbs for personalization
              final tempUser = UserModel(
                id: userForReplan.id,
                email: userForReplan.email,
                name: userForReplan.name,
                dateOfBirth: userForReplan.dateOfBirth,
                sex: userForReplan.sex,
                heightFeet: userForReplan.heightFeet,
                heightInches: userForReplan.heightInches,
                weight: weightLb,
                activityLevel: userForReplan.activityLevel,
                medicalConditions: userForReplan.medicalConditions,
                healthGoals: userForReplan.healthGoals,
              );

              final result = await _replanService!.generateNewPlan(tempUser);

              // Add small delay to allow connection to stabilize between operations
              await Future.delayed(const Duration(milliseconds: 200));

              await _mongoDBService.updateUserProfile(_currentUser!.id!, {
                'dietType': result.dietType,
                'myPlanType': result.myPlanType,
                'showGlycemicIndex': result.showGlycemicIndex,
                'targetCalories': result.targetCalories,
                'selectedDietPlan': result.selectedDietPlan,
                'diagnostics': result.diagnostics,
                'updatedAt': DateTime.now().toIso8601String(),
              });

              // Add small delay before refresh
              await Future.delayed(const Duration(milliseconds: 200));

              // Refresh user data with new plan
              final refreshedUser =
                  await _mongoDBService.findUserById(_currentUser!.id!);
              if (refreshedUser != null) {
                _currentUser = _createUserModel(refreshedUser);
              }

              // Clear pending trigger since we've handled it
              _pendingReplanTrigger = null;
            } catch (e) {
              debugPrint('Error auto-regenerating diet plan: $e');
              // Fall back to setting pending trigger if regeneration fails
              _pendingReplanTrigger = trigger;
            }
            notifyListeners();
          }
        }
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

  /// Generate a new personalized diet plan
  Future<bool> regenerateDietPlan() async {
    if (_currentUser == null || _replanService == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _replanService!.generateNewPlan(_currentUser!);

      // Update user with new diet plan
      await _mongoDBService.updateUserProfile(_currentUser!.id!, {
        'dietType': result.dietType,
        'myPlanType': result.myPlanType,
        'showGlycemicIndex': result.showGlycemicIndex,
        'targetCalories': result.targetCalories,
        'selectedDietPlan': result.selectedDietPlan,
        'diagnostics': result.diagnostics,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Refresh user data
      final updatedUser = await _mongoDBService.findUserById(_currentUser!.id!);
      if (updatedUser != null) {
        _currentUser = _createUserModel(updatedUser);
      }

      // Clear pending trigger
      _pendingReplanTrigger = null;
      return true;
    } catch (e) {
      _error = 'Failed to regenerate diet plan: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Dismiss the pending re-plan trigger
  void dismissReplanTrigger() {
    _pendingReplanTrigger = null;
    notifyListeners();
  }

  /// Check if user should be offered re-planning
  bool shouldOfferReplan() {
    if (_currentUser == null || _replanService == null) return false;
    return _replanService!.shouldOfferReplan(_currentUser!);
  }

  /// Get re-plan suggestions
  List<String> getReplanSuggestions() {
    if (_currentUser == null || _replanService == null) return [];
    return _replanService!.getReplanSuggestions(_currentUser!);
  }

  /// Initialize notification services for the user
  Future<void> _initializeNotificationServices(String userId) async {
    try {
      // Initialize notification manager (simplified)
      _notificationManager = NotificationManager();
      await _notificationManager!.initialize(userId);

      // Sync FCM token to database after user is logged in
      final notificationService = NotificationService();
      await notificationService.syncFCMTokenToDatabase();
    } catch (e) {
      debugPrint('Error initializing notification services: $e');
    }
  }

  /// Request a password reset for the given email
  /// Returns true if the request was processed (even if email doesn't exist, for security)
  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Generate reset token (this will return empty string if email doesn't exist)
      final token = await _mongoDBService.generatePasswordResetToken(email);

      // If token is empty, email doesn't exist, but we still return success
      // to prevent user enumeration attacks
      if (token.isEmpty) {
        // Still return true to maintain security (don't reveal if email exists)
        return true;
      }

      // Get user data for email personalization
      final user = await _mongoDBService.findUserByEmail(email);
      final userName = user?['name'] as String?;

      // Send password reset email
      final emailSent = await _emailService.sendPasswordResetEmail(
        email: email,
        resetToken: token,
        userName: userName,
      );

      if (!emailSent) {
        _error = 'Failed to send password reset email. Please try again later.';
        return false;
      }

      return true;
    } catch (e) {
      // Check if it's a rate limiting error
      if (e.toString().contains('Too many reset requests')) {
        _error = 'Too many reset requests. Please try again later.';
      } else {
        _error = 'Failed to process password reset request: $e';
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Validate a password reset token
  /// Returns true if token is valid and not expired
  Future<bool> validatePasswordResetToken(String token) async {
    _error = null;
    // Don't call notifyListeners() here to avoid build phase issues
    // The calling widget will handle state updates

    try {
      final tokenDoc = await _mongoDBService.validatePasswordResetToken(token);
      if (tokenDoc == null) {
        _error = 'Invalid or expired reset token';
        return false;
      }
      return true;
    } catch (e) {
      _error = 'Failed to validate reset token: $e';
      return false;
    }
    // Removed notifyListeners() to prevent build phase errors
  }

  /// Reset password using a valid reset token
  /// Returns true if password was successfully reset
  Future<bool> resetPassword(String token, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validate password requirements (same as signup)
      if (newPassword.length < 8) {
        _error = 'Password must be at least 8 characters';
        return false;
      }
      if (!newPassword.contains(RegExp(r'[A-Z]'))) {
        _error = 'Password must contain at least one uppercase letter';
        return false;
      }
      if (!newPassword.contains(RegExp(r'[a-z]'))) {
        _error = 'Password must contain at least one lowercase letter';
        return false;
      }
      if (!newPassword.contains(RegExp(r'[0-9]'))) {
        _error = 'Password must contain at least one number';
        return false;
      }
      if (!newPassword.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
        _error = 'Password must contain at least one special character';
        return false;
      }

      // Reset password in database
      final success = await _mongoDBService.resetPassword(token, newPassword);

      if (!success) {
        _error =
            'Invalid or expired reset token. Please request a new password reset.';
        return false;
      }

      // Clear any existing session after password reset
      // This ensures user must login with new password
      await _mongoDBService.clearSession();
      _currentUser = null;

      return true;
    } catch (e) {
      _error = 'Failed to reset password: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

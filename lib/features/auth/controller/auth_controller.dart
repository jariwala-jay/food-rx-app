import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/core/services/nutrition_content_loader.dart';
import 'package:flutter_app/core/services/personalization_service.dart';
import 'package:flutter_app/core/services/replan_service.dart';
import 'package:flutter_app/core/services/notification_manager.dart';
import 'package:flutter_app/core/services/notification_service.dart';
import 'package:flutter_app/core/services/email_service.dart';
import 'package:flutter_app/core/services/gmail_smtp_email_service.dart';

class AuthController with ChangeNotifier {
  final EmailService _emailService = GmailSMTPEmailService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  ReplanService? _replanService;
  ReplanTrigger? _pendingReplanTrigger;
  NotificationManager? _notificationManager;

  Future<void> _markUserActive() async {
    try {
      await ApiClient.patch('/auth/profile', body: {
        'lastActiveAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Non-blocking heartbeat; ignore failures.
    }
  }

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
      try {
        final nutritionContent = await NutritionContentLoader.load();
        final personalizationService = PersonalizationService(nutritionContent);
        _replanService = ReplanService(personalizationService);
      } catch (e) {
        debugPrint('Warning: Failed to initialize re-plan service: $e');
      }

      final token = await ApiClient.getToken();
      final userId = await ApiClient.userId;
      final userEmail = await ApiClient.userEmail;

      if (token != null && token.isNotEmpty && userId != null && userEmail != null) {
        try {
          if (userId.length != 24) {
            await ApiClient.clearSession();
            throw Exception('Invalid user ID format');
          }
          final userData = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
          if (userData != null && userData['email'] == userEmail) {
            _currentUser = _createUserModel(userData);
            await _initializeNotificationServices(_currentUser!.id!);
            unawaited(_markUserActive());
          } else {
            await ApiClient.clearSession();
          }
        } on ApiException catch (e) {
          if (e.statusCode == 401 || e.statusCode == 404) {
            await ApiClient.clearSession();
          } else {
            _error = 'Failed to restore session: ${e.message}';
          }
        } catch (e) {
          await ApiClient.clearSession();
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
    final id = userData['_id']?.toString() ?? '';
    return UserModel.fromJson({...userData, '_id': id});
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
      final cleanUserData = Map<String, dynamic>.from(userData);
      cleanUserData.remove('password');
      cleanUserData['email'] = email;
      cleanUserData['password'] = password;

      final res = await ApiClient.post('/auth/register', body: cleanUserData, requireAuth: false)
          as Map<String, dynamic>;
      final token = res['access_token'] as String?;
      final userId = res['user_id'] as String?;
      final emailRes = res['email'] as String?;
      final user = res['user'] as Map<String, dynamic>?;

      if (token != null && userId != null && emailRes != null) {
        await ApiClient.setSession(accessToken: token, userId: userId, email: emailRes);
        if (user != null) {
          _currentUser = _createUserModel(user);
        } else {
          final me = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
          if (me != null) _currentUser = _createUserModel(me);
        }

        if (profilePhoto != null) {
          try {
            final photoRes = await ApiClient.uploadFile('/auth/profile-photo', profilePhoto)
                as Map<String, dynamic>?;
            final photoId = photoRes?['profilePhotoId'] as String?;
            if (photoId != null) {
              await ApiClient.patch('/auth/profile', body: {'profilePhotoId': photoId});
              final updated = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
              if (updated != null) _currentUser = _createUserModel(updated);
            }
          } catch (e) {
            debugPrint('Warning: Failed to upload profile photo: $e');
          }
        }

        // Kick off notification initialization without blocking
        try {
          unawaited(_initializeNotificationServices(_currentUser!.id!));
        } catch (e) {
          debugPrint('Warning: Failed to initialize notification services: $e');
        }
        return true;
      }
      _error = 'Registration failed';
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } on SocketException catch (_) {
      _error = 'Could not reach server. Check that the backend is running and '
          'API_BASE_URL is correct (e.g. http://localhost:8000 for iOS Simulator).';
      return false;
    } on TimeoutException catch (_) {
      _error = 'Connection timed out. Is the backend running at API_BASE_URL?';
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
    if (email.trim().isEmpty) return false;
    try {
      final res = await ApiClient.post(
        '/auth/check-email',
        body: {'email': email.trim().toLowerCase()},
        requireAuth: false,
      ) as Map<String, dynamic>?;
      return res?['exists'] == true;
    } catch (_) {
      return false; // On error, allow user to proceed; register will fail if duplicate
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/auth/login', body: {'email': email, 'password': password},
              requireAuth: false)
          as Map<String, dynamic>?;
      final token = res?['access_token'] as String?;
      final userId = res?['user_id'] as String?;
      final emailRes = res?['email'] as String?;
      final user = res?['user'] as Map<String, dynamic>?;

      if (token != null && userId != null && emailRes != null) {
        await ApiClient.setSession(accessToken: token, userId: userId, email: emailRes);
        if (user != null) {
          _currentUser = _createUserModel(user);
        } else {
          final me = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
          if (me != null) _currentUser = _createUserModel(me);
        }
        try {
          await _initializeNotificationServices(_currentUser!.id!);
        } catch (e) {
          debugPrint('Warning: Failed to initialize notification services: $e');
        }
        unawaited(_markUserActive());
        return true;
      }
      _error = 'Invalid email or password';
      return false;
    } on ApiException catch (e) {
      if (e.statusCode == 401) _error = 'Invalid email or password';
      else _error = e.message;
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
      await ApiClient.clearSession();
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
      await ApiClient.patch('/auth/profile', body: updates);
      final updatedUser = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
      if (updatedUser != null) {
        final oldUser = _currentUser!;
        _currentUser = _createUserModel(updatedUser);
        if (_replanService != null) {
          final trigger = await _replanService!.checkReplanTriggers(oldUser, _currentUser!);
          if (trigger != null) {
            try {
              final userForReplan = _currentUser!;
              double? weightLb = userForReplan.weight;
              if (weightLb != null && userForReplan.weightUnit == 'kg') {
                weightLb = weightLb * 2.205;
              }
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
              await ApiClient.patch('/auth/profile', body: {
                'dietType': result.dietType,
                'myPlanType': result.myPlanType,
                'showGlycemicIndex': result.showGlycemicIndex,
                'targetCalories': result.targetCalories,
                'selectedDietPlan': result.selectedDietPlan,
                'diagnostics': result.diagnostics,
              });
              final refreshed = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
              if (refreshed != null) _currentUser = _createUserModel(refreshed);
              _pendingReplanTrigger = null;
            } catch (e) {
              debugPrint('Error auto-regenerating diet plan: $e');
              _pendingReplanTrigger = trigger;
            }
            notifyListeners();
          }
        }
      }
    } on ApiException catch (e) {
      _error = e.message;
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
      final photoRes = await ApiClient.uploadFile('/auth/profile-photo', photo)
          as Map<String, dynamic>?;
      final photoId = photoRes?['profilePhotoId'] as String?;
      if (photoId != null) {
        await ApiClient.patch('/auth/profile', body: {'profilePhotoId': photoId});
        final updated = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
        if (updated != null) _currentUser = _createUserModel(updated);
      }
    } on ApiException catch (e) {
      _error = e.message;
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
      return await ApiClient.getBytes('/api/profile-photos/${_currentUser!.profilePhotoId}');
    } catch (e) {
      _error = 'Failed to get profile photo: $e';
      return null;
    }
  }

  Future<bool> regenerateDietPlan() async {
    if (_currentUser == null || _replanService == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _replanService!.generateNewPlan(_currentUser!);
      await ApiClient.patch('/auth/profile', body: {
        'dietType': result.dietType,
        'myPlanType': result.myPlanType,
        'showGlycemicIndex': result.showGlycemicIndex,
        'targetCalories': result.targetCalories,
        'selectedDietPlan': result.selectedDietPlan,
        'diagnostics': result.diagnostics,
      });
      final updated = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
      if (updated != null) _currentUser = _createUserModel(updated);
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

  void dismissReplanTrigger() {
    _pendingReplanTrigger = null;
    notifyListeners();
  }

  bool shouldOfferReplan() {
    if (_currentUser == null || _replanService == null) return false;
    return _replanService!.shouldOfferReplan(_currentUser!);
  }

  List<String> getReplanSuggestions() {
    if (_currentUser == null || _replanService == null) return [];
    return _replanService!.getReplanSuggestions(_currentUser!);
  }

  Future<void> _initializeNotificationServices(String userId) async {
    try {
      _notificationManager = NotificationManager();
      await _notificationManager!.initialize(userId);
      final notificationService = NotificationService();
      await notificationService.syncFCMTokenToDatabase();
    } catch (e) {
      debugPrint('Error initializing notification services: $e');
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.post('/auth/forgot-password',
          body: {'email': email}, requireAuth: false) as Map<String, dynamic>?;
      final token = res?['token'] as String?;
      if (token != null && token.isNotEmpty) {
        final userName = res?['userName'] as String?;
        final emailSent = await _emailService.sendPasswordResetEmail(
          email: email,
          resetToken: token,
          userName: userName,
        );
        if (!emailSent) {
          _error = 'Failed to send password reset email. Please try again later.';
          return false;
        }
      }
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 429) _error = 'Too many reset requests. Please try again later.';
      else _error = e.message;
      return false;
    } catch (e) {
      _error = 'Failed to process password reset request: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> validatePasswordResetToken(String token) async {
    _error = null;
    try {
      final res = await ApiClient.post('/auth/validate-reset-token',
          body: {'token': token}, requireAuth: false) as Map<String, dynamic>?;
      return res?['valid'] == true;
    } catch (e) {
      _error = 'Invalid or expired reset token';
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
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
      await ApiClient.post('/auth/reset-password',
          body: {'token': token, 'newPassword': newPassword}, requireAuth: false);
      await ApiClient.clearSession();
      _currentUser = null;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Failed to reset password: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

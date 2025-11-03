// lib/features/tracking/controller/tracker_provider.dart

import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/tracker_goal.dart';
import '../models/tracker_progress.dart';
import '../services/tracker_service.dart';
import '../services/tracker_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrackerProvider extends ChangeNotifier {
  final TrackerService _trackerService = TrackerService();
  final TrackerProgressService _progressService = TrackerProgressService();
  // final TrackerResetScheduler _resetScheduler = TrackerResetScheduler(); // REMOVED: Client-side scheduler

  List<TrackerGoal> _dailyTrackers = [];
  List<TrackerGoal> _weeklyTrackers = [];
  bool _isLoading = false;
  String? _error;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  String?
      _currentLoadingDietType; // Track what diet type is currently being loaded
  String? _lastLoadedDietType; // Track last successfully loaded diet type

  List<TrackerGoal> get dailyTrackers => _dailyTrackers;
  List<TrackerGoal> get weeklyTrackers => _weeklyTrackers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Clear tracker state (useful when diet type changes)
  void clearTrackers() {
    _dailyTrackers = [];
    _weeklyTrackers = [];
    _error = null;
    _retryCount = 0;
    _lastLoadedDietType = null; // Reset last loaded diet type
    _currentLoadingDietType = null; // Reset current loading
    notifyListeners();
  }

  // Add this clearError method
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> initializeUserTrackers(String userId, String dietType,
      {Map<String, dynamic>? personalizedDietPlan}) async {
    _setError(null);
    _setLoading(true);
    try {
      // This call to _trackerService.initializeUserTrackers should handle provisioning
      // default trackers if none exist for the user on the backend.
      await _trackerService
          .initializeUserTrackers(userId, dietType,
              personalizedDietPlan: personalizedDietPlan)
          .timeout(const Duration(seconds: 20), onTimeout: () {
        throw TimeoutException(
            'Tracker initialization timed out after 20 seconds');
      });

      await loadUserTrackers(userId, dietType);
      _retryCount = 0;
    } catch (e) {
      String errorMsg;

      if (e is TimeoutException) {
        errorMsg =
            'Tracker initialization timed out. Please check your connection and try again.';
      } else {
        errorMsg = 'Failed to initialize trackers: ${e.toString()}';
      }

      _setError(errorMsg);

      if (_retryCount < _maxRetries) {
        _retryCount++;
        await Future.delayed(Duration(seconds: 2 * _retryCount));
        await initializeUserTrackers(userId, dietType,
            personalizedDietPlan: personalizedDietPlan);
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadUserTrackers(String userId, String dietType,
      {Map<String, dynamic>? personalizedDietPlan,
      bool forceReload = false}) async {
    // Prevent concurrent loads for the same diet type (unless forced)
    if (!forceReload && _isLoading && _currentLoadingDietType == dietType) {
      return;
    }

    // If forced reload, clear state first
    if (forceReload) {
      _dailyTrackers = [];
      _weeklyTrackers = [];
      _lastLoadedDietType = null;
      _currentLoadingDietType = null;
      await _trackerService.clearUserTrackerCache(userId);
    }

    // If we're already loaded with this diet type, skip reload (unless forced)
    if (!forceReload &&
        _lastLoadedDietType == dietType &&
        (_dailyTrackers.isNotEmpty || _weeklyTrackers.isEmpty)) {
      final allTrackers = [..._dailyTrackers, ..._weeklyTrackers];
      if (allTrackers.isNotEmpty &&
          allTrackers.every((t) => t.dietType == dietType)) {
        return;
      }
    }

    _setError(null);
    _setLoading(true);
    _currentLoadingDietType = dietType;

    try {
      // First, clear any stale cache entries if diet type might have changed
      // This ensures we don't load old trackers from a previous diet type

      // Try loading from local cache first (with strict diet type validation)
      // Skip cache if force reload is requested
      if (!forceReload) {
        try {
          _dailyTrackers =
              await _trackerService.getDailyTrackers(userId, dietType);
          _weeklyTrackers =
              await _trackerService.getWeeklyTrackers(userId, dietType);

          // Strictly verify trackers match the requested diet type
          final allTrackers = [..._dailyTrackers, ..._weeklyTrackers];
          final hasMatchingDietType = allTrackers.isNotEmpty &&
              allTrackers.every((t) => t.dietType == dietType);

          if (hasMatchingDietType &&
              (_dailyTrackers.isNotEmpty || _weeklyTrackers.isNotEmpty)) {
            // If personalized diet plan is provided, validate tracker values match
            // Don't return early if we need to update trackers with new plan values
            bool shouldUpdateForPersonalizedPlan = false;
            if (personalizedDietPlan != null) {
              for (final tracker in _dailyTrackers) {
                final categoryName = tracker.category.name.toLowerCase();
                double? expectedValue;

                if (dietType == 'DASH') {
                  if (categoryName == 'vegetables' ||
                      categoryName == 'veggies') {
                    expectedValue =
                        (personalizedDietPlan['vegetablesMax'] as num?)
                            ?.toDouble();
                  } else if (categoryName == 'fruits') {
                    expectedValue =
                        (personalizedDietPlan['fruitsMax'] as num?)?.toDouble();
                  } else if (categoryName == 'grains') {
                    expectedValue =
                        (personalizedDietPlan['grainsMax'] as num?)?.toDouble();
                  } else if (categoryName == 'dairy') {
                    expectedValue =
                        (personalizedDietPlan['dairyMax'] as num?)?.toDouble();
                  }
                } else if (dietType == 'MyPlate') {
                  if (categoryName == 'vegetables' ||
                      categoryName == 'veggies') {
                    expectedValue = (personalizedDietPlan['vegetables'] as num?)
                        ?.toDouble();
                  } else if (categoryName == 'fruits') {
                    expectedValue =
                        (personalizedDietPlan['fruits'] as num?)?.toDouble();
                  } else if (categoryName == 'grains') {
                    expectedValue =
                        (personalizedDietPlan['grains'] as num?)?.toDouble();
                  } else if (categoryName == 'protein') {
                    expectedValue =
                        (personalizedDietPlan['protein'] as num?)?.toDouble();
                  } else if (categoryName == 'dairy') {
                    expectedValue =
                        (personalizedDietPlan['dairy'] as num?)?.toDouble();
                  }
                }

                if (expectedValue != null &&
                    (tracker.goalValue - expectedValue).abs() > 0.1) {
                  shouldUpdateForPersonalizedPlan = true;
                  break;
                }
              }
            }

            // Only return early if trackers are valid AND match personalized plan (if provided)
            if (!shouldUpdateForPersonalizedPlan) {
              _retryCount = 0;
              _lastLoadedDietType = dietType;
              _currentLoadingDietType = null;
              _setLoading(false);
              notifyListeners();
              // Try to sync with the database in the background
              _syncWithDatabase(
                  userId, dietType); // Keep this for eventual consistency
              return;
            } else {
              // Clear cached trackers if they don't match personalized plan
              _dailyTrackers = [];
              _weeklyTrackers = [];
              await _trackerService.clearUserTrackerCache(userId);
            }
          } else if (allTrackers.isNotEmpty && !hasMatchingDietType) {
            // Clear mismatched trackers - this indicates stale cache
            _dailyTrackers = [];
            _weeklyTrackers = [];
            // Clear all cache for this user to prevent future conflicts
            await _trackerService.clearUserTrackerCache(userId);
          }
        } catch (localError) {
          // Clear cache on error and continue to database
          await _trackerService.clearUserTrackerCache(userId);
        }
      } // End of forceReload check for cache

      // Clean up duplicates if possible (non-critical, can run in background)
      try {
        await _trackerService.cleanupDuplicateTrackers(userId);
      } catch (e) {
        // Silently fail - cleanup is non-critical
      }

      // Always attempt to fetch from MongoDB to get the latest state
      // This ensures we have the most up-to-date trackers for the current diet type
      try {
        _dailyTrackers =
            await _trackerService.getDailyTrackers(userId, dietType);
        _weeklyTrackers =
            await _trackerService.getWeeklyTrackers(userId, dietType);

        // If personalized diet plan is provided and we're forcing a reload,
        // ALWAYS reinitialize trackers with new personalized values
        // This ensures we get fresh trackers with correct values, not updates to old ones
        if (forceReload && personalizedDietPlan != null) {
          // Clear cache again before reinitializing to ensure no stale data
          await _trackerService.clearUserTrackerCache(userId);
          // Delete existing trackers and create new ones with personalized values
          // This is more reliable than trying to update existing trackers
          await _initializeDefaultTrackers(userId, dietType,
              personalizedDietPlan: personalizedDietPlan);
          // Reload trackers after reinitialization to get fresh values
          _dailyTrackers =
              await _trackerService.getDailyTrackers(userId, dietType);
          _weeklyTrackers =
              await _trackerService.getWeeklyTrackers(userId, dietType);
        }
      } catch (e) {
        print('❌ Error loading from database: $e');
        throw Exception('Failed to load trackers from database: $e');
      }

      // Verify trackers match the requested diet type (critical validation)
      final allTrackers = [..._dailyTrackers, ..._weeklyTrackers];
      final hasMatchingDietType = allTrackers.isNotEmpty &&
          allTrackers.every((t) => t.dietType == dietType);

      // If trackers are empty OR don't match diet type, initialize new ones
      if (_dailyTrackers.isEmpty && _weeklyTrackers.isEmpty) {
        await _initializeDefaultTrackers(userId, dietType,
            personalizedDietPlan: personalizedDietPlan);
        // Reload after initialization to get the newly created trackers
        _dailyTrackers =
            await _trackerService.getDailyTrackers(userId, dietType);
        _weeklyTrackers =
            await _trackerService.getWeeklyTrackers(userId, dietType);
      } else if (!hasMatchingDietType) {
        // Clear mismatched trackers from provider
        _dailyTrackers = [];
        _weeklyTrackers = [];
        // Clear cache to prevent future conflicts
        await _trackerService.clearUserTrackerCache(userId);
        // Initialize with correct diet type
        await _initializeDefaultTrackers(userId, dietType,
            personalizedDietPlan: personalizedDietPlan);
        // Reload after initialization to get the newly created trackers
        _dailyTrackers =
            await _trackerService.getDailyTrackers(userId, dietType);
        _weeklyTrackers =
            await _trackerService.getWeeklyTrackers(userId, dietType);
      } else if (personalizedDietPlan != null) {
        // Trackers are valid and match diet type, check if they need personalized updates
        // Compare current tracker values with personalized diet plan values
        bool needsUpdate = false;

        // Check if tracker values don't match personalized plan values
        for (final tracker in _dailyTrackers) {
          final categoryName = tracker.category.name.toLowerCase();
          double? expectedValue;

          // Map category names to personalized diet plan keys
          if (dietType == 'DASH') {
            if (categoryName == 'vegetables' || categoryName == 'veggies') {
              expectedValue =
                  (personalizedDietPlan['vegetablesMax'] as num?)?.toDouble();
            } else if (categoryName == 'fruits') {
              expectedValue =
                  (personalizedDietPlan['fruitsMax'] as num?)?.toDouble();
            } else if (categoryName == 'grains') {
              expectedValue =
                  (personalizedDietPlan['grainsMax'] as num?)?.toDouble();
            } else if (categoryName == 'dairy') {
              expectedValue =
                  (personalizedDietPlan['dairyMax'] as num?)?.toDouble();
            }
          } else if (dietType == 'MyPlate') {
            if (categoryName == 'vegetables' || categoryName == 'veggies') {
              expectedValue =
                  (personalizedDietPlan['vegetables'] as num?)?.toDouble();
            } else if (categoryName == 'fruits') {
              expectedValue =
                  (personalizedDietPlan['fruits'] as num?)?.toDouble();
            } else if (categoryName == 'grains') {
              expectedValue =
                  (personalizedDietPlan['grains'] as num?)?.toDouble();
            } else if (categoryName == 'protein') {
              expectedValue =
                  (personalizedDietPlan['protein'] as num?)?.toDouble();
            } else if (categoryName == 'dairy') {
              expectedValue =
                  (personalizedDietPlan['dairy'] as num?)?.toDouble();
            }
          }

          // If expected value exists and doesn't match tracker value (within 0.1 tolerance), need update
          if (expectedValue != null &&
              (tracker.goalValue - expectedValue).abs() > 0.1) {
            needsUpdate = true;
            break;
          }
        }

        if (needsUpdate) {
          // Clear cache first to ensure fresh load
          await _trackerService.clearUserTrackerCache(userId);
          // Update trackers with personalized values
          await _trackerService.updateTrackersWithPersonalizedPlan(
              userId, dietType, personalizedDietPlan);
          // Reload trackers after update
          _dailyTrackers =
              await _trackerService.getDailyTrackers(userId, dietType);
          _weeklyTrackers =
              await _trackerService.getWeeklyTrackers(userId, dietType);
        }
      }

      _retryCount = 0;
      _lastLoadedDietType = dietType;
      _currentLoadingDietType = null;
      notifyListeners();
    } catch (e) {
      String errorMsg;

      if (e is TimeoutException) {
        errorMsg =
            'Loading trackers timed out. Please check your connection and try again.';
      } else if (e.toString().contains('MongoDB connection failed') ||
          e.toString().contains('Database connection failed')) {
        errorMsg =
            'Could not connect to the database. Please check your internet connection and try again.';
      } else {
        errorMsg = 'Failed to load trackers: ${e.toString()}';
      }

      _setError(errorMsg);

      if (_retryCount < _maxRetries) {
        _retryCount++;
        await Future.delayed(Duration(seconds: 2 * _retryCount));
        await loadUserTrackers(userId, dietType);
      }
    } finally {
      _setLoading(false);
    }
  }

  // Try to initialize default trackers
  Future<void> _initializeDefaultTrackers(String userId, String dietType,
      {Map<String, dynamic>? personalizedDietPlan}) async {
    final prefs = await SharedPreferences.getInstance();
    final initKey = 'tracker_init_$userId';
    final alreadyInitializing = prefs.getBool(initKey) ?? false;

    if (!alreadyInitializing) {
      await prefs.setBool(initKey, true);

      try {
        await _trackerService
            .initializeUserTrackers(userId, dietType,
                personalizedDietPlan: personalizedDietPlan)
            .timeout(const Duration(seconds: 30));

        // Reload trackers after initialization
        _dailyTrackers =
            await _trackerService.getDailyTrackers(userId, dietType);
        _weeklyTrackers =
            await _trackerService.getWeeklyTrackers(userId, dietType);
      } catch (e) {
        // On error, ensure we have empty trackers, not stale ones
        _dailyTrackers = [];
        _weeklyTrackers = [];
      } finally {
        await prefs.remove(initKey);
      }
    } else {
      // Someone else is already initializing, wait and retry
      await Future.delayed(const Duration(seconds: 3));
      try {
        _dailyTrackers =
            await _trackerService.getDailyTrackers(userId, dietType);
        _weeklyTrackers =
            await _trackerService.getWeeklyTrackers(userId, dietType);
      } catch (e) {
      }
    }
  }

  // Attempt to sync local data with the database
  // This method remains for ensuring cache consistency but the primary reset is backend.
  Future<void> _syncWithDatabase(String userId, String dietType) async {
    try {
      // Add a small delay to allow any pending MongoDB updates to complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Reload from database
      final dbDailyTrackers =
          await _trackerService.getDailyTrackers(userId, dietType);
      final dbWeeklyTrackers =
          await _trackerService.getWeeklyTrackers(userId, dietType);

      // Check if there are any differences, but be smart about which values to use
      bool needsUpdate = false;
      List<TrackerGoal> updatedDailyTrackers = [];
      List<TrackerGoal> updatedWeeklyTrackers = [];

      // For daily trackers, use the most recent values
      for (int i = 0;
          i < _dailyTrackers.length && i < dbDailyTrackers.length;
          i++) {
        final localTracker = _dailyTrackers[i];
        final dbTracker = dbDailyTrackers[i];

        // Use the tracker with the most recent lastUpdated timestamp
        if (localTracker.lastUpdated.isAfter(dbTracker.lastUpdated)) {
          // Local is more recent, keep local value
          updatedDailyTrackers.add(localTracker);
          if (localTracker.currentValue != dbTracker.currentValue) {
            needsUpdate = true;
          }
        } else if (dbTracker.lastUpdated.isAfter(localTracker.lastUpdated)) {
          // Database is more recent, use database value
          updatedDailyTrackers.add(dbTracker);
          if (localTracker.currentValue != dbTracker.currentValue) {
            needsUpdate = true;
          }
        } else {
          // Same timestamp, use the higher value (assuming incremental updates)
          if (dbTracker.currentValue >= localTracker.currentValue) {
            updatedDailyTrackers.add(dbTracker);
          } else {
            updatedDailyTrackers.add(localTracker);
          }
          if (localTracker.currentValue != dbTracker.currentValue) {
            needsUpdate = true;
          }
        }
      }

      // Handle any extra trackers
      if (dbDailyTrackers.length > _dailyTrackers.length) {
        updatedDailyTrackers
            .addAll(dbDailyTrackers.skip(_dailyTrackers.length));
        needsUpdate = true;
      } else if (_dailyTrackers.length > dbDailyTrackers.length) {
        updatedDailyTrackers
            .addAll(_dailyTrackers.skip(dbDailyTrackers.length));
      }

      // For weekly trackers, use the same logic
      for (int i = 0;
          i < _weeklyTrackers.length && i < dbWeeklyTrackers.length;
          i++) {
        final localTracker = _weeklyTrackers[i];
        final dbTracker = dbWeeklyTrackers[i];

        // Use the tracker with the most recent lastUpdated timestamp
        if (localTracker.lastUpdated.isAfter(dbTracker.lastUpdated)) {
          // Local is more recent, keep local value
          updatedWeeklyTrackers.add(localTracker);
          if (localTracker.currentValue != dbTracker.currentValue) {
            needsUpdate = true;
          }
        } else if (dbTracker.lastUpdated.isAfter(localTracker.lastUpdated)) {
          // Database is more recent, use database value
          updatedWeeklyTrackers.add(dbTracker);
          if (localTracker.currentValue != dbTracker.currentValue) {
            needsUpdate = true;
          }
        } else {
          // Same timestamp, use the higher value (assuming incremental updates)
          if (dbTracker.currentValue >= localTracker.currentValue) {
            updatedWeeklyTrackers.add(dbTracker);
          } else {
            updatedWeeklyTrackers.add(localTracker);
          }
          if (localTracker.currentValue != dbTracker.currentValue) {
            needsUpdate = true;
          }
        }
      }

      // Handle any extra trackers
      if (dbWeeklyTrackers.length > _weeklyTrackers.length) {
        updatedWeeklyTrackers
            .addAll(dbWeeklyTrackers.skip(_weeklyTrackers.length));
        needsUpdate = true;
      } else if (_weeklyTrackers.length > dbWeeklyTrackers.length) {
        updatedWeeklyTrackers
            .addAll(_weeklyTrackers.skip(dbWeeklyTrackers.length));
      }

      // Only update if there are actual differences and we have valid data
      if (needsUpdate &&
          (updatedDailyTrackers.isNotEmpty ||
              updatedWeeklyTrackers.isNotEmpty)) {
        _dailyTrackers = updatedDailyTrackers;
        _weeklyTrackers = updatedWeeklyTrackers;

        notifyListeners();
      }
    } catch (e) {
      // Silently fail - sync is non-critical background operation
    }
  }

  Future<void> updateTrackerValue(String trackerId, double newValue) async {
    _setLoading(true);
    _setError(null);

    try {
      // Update the tracker value in the service
      await _trackerService.updateTrackerValue(trackerId, newValue);

      // Update the local tracker immediately for better UX
      _updateLocalTrackerValue(trackerId, newValue);
    } catch (e) {
      _setError('Failed to update tracker: $e');
      // Try to reload the specific tracker even if update failed
      await _reloadSpecificTracker(trackerId);
    } finally {
      _setLoading(false);
    }
  }

  // Optimized method for updating tracker values without loading states
  Future<void> updateTrackerValueOptimized(
      String trackerId, double newValue) async {
    try {
      // Update the local tracker immediately for instant UI response
      _updateLocalTrackerValue(trackerId, newValue);

      // Update the tracker value in the service in the background
      await _trackerService.updateTrackerValue(trackerId, newValue);
    } catch (e) {
      // If service update fails, try to reload the specific tracker
      await _reloadSpecificTracker(trackerId);
    }
  }

  // Helper method to update local tracker value without full reload
  void _updateLocalTrackerValue(String trackerId, double newValue) {
    // Clean the tracker ID to handle ObjectId format
    String cleanId = trackerId;
    if (trackerId.startsWith('ObjectId("') && trackerId.endsWith('")')) {
      cleanId = trackerId.substring(9, trackerId.length - 2);
    }

    // Update daily trackers
    for (int i = 0; i < _dailyTrackers.length; i++) {
      if (_dailyTrackers[i].id == trackerId ||
          _dailyTrackers[i].id == cleanId) {
        _dailyTrackers[i] = _dailyTrackers[i].copyWith(
          currentValue: newValue,
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
        return;
      }
    }

    // Update weekly trackers if not found in daily
    for (int i = 0; i < _weeklyTrackers.length; i++) {
      if (_weeklyTrackers[i].id == trackerId ||
          _weeklyTrackers[i].id == cleanId) {
        _weeklyTrackers[i] = _weeklyTrackers[i].copyWith(
          currentValue: newValue,
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
        return;
      }
    }
  }

  // Method to update a specific tracker's goal value without full reload
  void updateTrackerGoal(String trackerId, double newGoalValue) {
    // Clean the tracker ID to handle ObjectId format
    String cleanId = trackerId;
    if (trackerId.startsWith('ObjectId("') && trackerId.endsWith('")')) {
      cleanId = trackerId.substring(9, trackerId.length - 2);
    }

    // Update daily trackers
    for (int i = 0; i < _dailyTrackers.length; i++) {
      if (_dailyTrackers[i].id == trackerId ||
          _dailyTrackers[i].id == cleanId) {
        _dailyTrackers[i] = _dailyTrackers[i].copyWith(
          goalValue: newGoalValue,
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
        return;
      }
    }

    // Update weekly trackers if not found in daily
    for (int i = 0; i < _weeklyTrackers.length; i++) {
      if (_weeklyTrackers[i].id == trackerId ||
          _weeklyTrackers[i].id == cleanId) {
        _weeklyTrackers[i] = _weeklyTrackers[i].copyWith(
          goalValue: newGoalValue,
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
        return;
      }
    }
  }

  // Method to update a specific tracker's name without full reload
  void updateTrackerName(String trackerId, String newName) {
    // Clean the tracker ID to handle ObjectId format
    String cleanId = trackerId;
    if (trackerId.startsWith('ObjectId("') && trackerId.endsWith('")')) {
      cleanId = trackerId.substring(9, trackerId.length - 2);
    }

    // Update daily trackers
    for (int i = 0; i < _dailyTrackers.length; i++) {
      if (_dailyTrackers[i].id == trackerId ||
          _dailyTrackers[i].id == cleanId) {
        _dailyTrackers[i] = _dailyTrackers[i].copyWith(
          name: newName,
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
        return;
      }
    }

    // Update weekly trackers if not found in daily
    for (int i = 0; i < _weeklyTrackers.length; i++) {
      if (_weeklyTrackers[i].id == trackerId ||
          _weeklyTrackers[i].id == cleanId) {
        _weeklyTrackers[i] = _weeklyTrackers[i].copyWith(
          name: newName,
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
        return;
      }
    }
  }

  // Method to update multiple trackers at once without full reload
  void updateMultipleTrackers(Map<String, double> trackerUpdates) {
    bool hasUpdates = false;
    final now = DateTime.now();

    // Update daily trackers
    for (int i = 0; i < _dailyTrackers.length; i++) {
      final tracker = _dailyTrackers[i];
      if (trackerUpdates.containsKey(tracker.id)) {
        _dailyTrackers[i] = tracker.copyWith(
          currentValue: trackerUpdates[tracker.id]!,
          lastUpdated: now,
        );
        hasUpdates = true;
      }
    }

    // Update weekly trackers
    for (int i = 0; i < _weeklyTrackers.length; i++) {
      final tracker = _weeklyTrackers[i];
      if (trackerUpdates.containsKey(tracker.id)) {
        _weeklyTrackers[i] = tracker.copyWith(
          currentValue: trackerUpdates[tracker.id]!,
          lastUpdated: now,
        );
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      notifyListeners();
    }
  }

  // Helper method to reload only a specific tracker
  Future<void> _reloadSpecificTracker(String trackerId) async {
    if (_dailyTrackers.isEmpty && _weeklyTrackers.isEmpty) return;

    final userId = _dailyTrackers.isNotEmpty
        ? _dailyTrackers.first.userId
        : _weeklyTrackers.first.userId;

    final dietType = _dailyTrackers.isNotEmpty
        ? _dailyTrackers.first.dietType
        : _weeklyTrackers.first.dietType;

    try {
      // Check daily trackers first
      var trackers = await _trackerService.getDailyTrackers(userId, dietType);
      final dailyTracker = trackers.where((t) => t.id == trackerId).firstOrNull;

      if (dailyTracker != null) {
        final index = _dailyTrackers.indexWhere((t) => t.id == trackerId);
        if (index >= 0) {
          _dailyTrackers[index] = dailyTracker;
          notifyListeners();
          return;
        }
      }

      // Check weekly trackers if not found in daily
      trackers = await _trackerService.getWeeklyTrackers(userId, dietType);
      final weeklyTracker =
          trackers.where((t) => t.id == trackerId).firstOrNull;

      if (weeklyTracker != null) {
        final index = _weeklyTrackers.indexWhere((t) => t.id == trackerId);
        if (index >= 0) {
          _weeklyTrackers[index] = weeklyTracker;
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      print('Error reloading tracker ${trackerId}: $e');
      _setError('Failed to reload tracker: $e');
    }
  }

  Future<void> incrementTracker(String trackerId, double amount) async {
    final dailyIndex = _dailyTrackers.indexWhere((t) => t.id == trackerId);
    final weeklyIndex = _weeklyTrackers.indexWhere((t) => t.id == trackerId);

    double currentValue = 0;

    if (dailyIndex >= 0) {
      currentValue = _dailyTrackers[dailyIndex].currentValue;
    } else if (weeklyIndex >= 0) {
      currentValue = _weeklyTrackers[weeklyIndex].currentValue;
    } else {
      _setError('Tracker not found');
      return;
    }

    final newValue = currentValue + amount;
    await updateTrackerValueOptimized(trackerId, newValue);
  }

  Future<void> resetDailyTrackers(String userId) async {
    _setLoading(true);
    try {
      await _trackerService.resetDailyTrackers(userId);

      // Update local trackers immediately
      for (int i = 0; i < _dailyTrackers.length; i++) {
        _dailyTrackers[i] = _dailyTrackers[i].copyWith(
          currentValue: 0,
          lastUpdated: DateTime.now(),
        );
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to reset daily trackers: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetWeeklyTrackers(String userId) async {
    _setLoading(true);
    try {
      await _trackerService.resetWeeklyTrackers(userId);

      // Update local trackers immediately
      for (int i = 0; i < _weeklyTrackers.length; i++) {
        _weeklyTrackers[i] = _weeklyTrackers[i].copyWith(
          currentValue: 0,
          lastUpdated: DateTime.now(),
        );
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to reset weekly trackers: $e');
    } finally {
      _setLoading(false);
    }
  }

  TrackerGoal? findTrackerById(String trackerId) {
    // Clean the tracker ID to handle ObjectId format
    String cleanId = trackerId;
    if (trackerId.startsWith('ObjectId("') && trackerId.endsWith('")')) {
      cleanId = trackerId.substring(9, trackerId.length - 2);
    }

    final dailyTracker = _dailyTrackers
        .where((t) => t.id == trackerId || t.id == cleanId)
        .firstOrNull;
    if (dailyTracker != null) {
      return dailyTracker;
    }

    final weeklyTracker = _weeklyTrackers
        .where((t) => t.id == trackerId || t.id == cleanId)
        .firstOrNull;
    if (weeklyTracker != null) {
      return weeklyTracker;
    }

    return null;
  }

  TrackerGoal? findTrackerByCategory(
      TrackerCategory category, String dietType) {
    // First check daily trackers
    final dailyTracker = _dailyTrackers
        .where((t) =>
            t.category == category &&
            t.dietType.toLowerCase() == dietType.toLowerCase())
        .firstOrNull;
    if (dailyTracker != null) return dailyTracker;

    // Then check weekly trackers
    return _weeklyTrackers
        .where((t) =>
            t.category == category &&
            t.dietType.toLowerCase() == dietType.toLowerCase())
        .firstOrNull;
  }

  // Analytics and Historical Data Methods

  /// Get progress history for analytics
  Future<List<TrackerProgress>> getProgressHistory({
    required String userId,
    String? trackerId,
    ProgressPeriodType? periodType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      return await _progressService.getProgressHistory(
        userId: userId,
        trackerId: trackerId,
        periodType: periodType,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
    } catch (e) {
      print('Error getting progress history: $e');
      return [];
    }
  }

  /// Get weekly summary for a specific week
  Future<List<TrackerProgress>> getWeeklySummary(
      String userId, DateTime weekStart) async {
    try {
      return await _progressService.getWeeklySummary(userId, weekStart);
    } catch (e) {
      print('Error getting weekly summary: $e');
      return [];
    }
  }

  /// Update trackers with personalized diet plan
  Future<void> updateTrackersWithPersonalizedPlan(String userId,
      String dietType, Map<String, dynamic> personalizedDietPlan) async {
    _setLoading(true);
    _setError(null);

    try {
      await _trackerService.updateTrackersWithPersonalizedPlan(
          userId, dietType, personalizedDietPlan);

      // Reload trackers to get the updated values
      await loadUserTrackers(userId, dietType);
    } catch (e) {
      _setError('Failed to update trackers with personalized plan: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Get monthly summary
  Future<List<TrackerProgress>> getMonthlySummary(
      String userId, DateTime month) async {
    try {
      return await _progressService.getMonthlySummary(userId, month);
    } catch (e) {
      print('Error getting monthly summary: $e');
      return [];
    }
  }

  /// Get analytics for a specific tracker
  Future<TrackerAnalytics> getTrackerAnalytics({
    required String userId,
    required String trackerId,
    required DateTime startDate,
    required DateTime endDate,
    ProgressPeriodType periodType = ProgressPeriodType.daily,
  }) async {
    try {
      return await _progressService.getTrackerAnalytics(
        userId: userId,
        trackerId: trackerId,
        startDate: startDate,
        endDate: endDate,
        periodType: periodType,
      );
    } catch (e) {
      print('Error getting tracker analytics: $e');
      return TrackerAnalytics.fromProgressHistory([], startDate, endDate);
    }
  }

  /// Get completion rates for all trackers
  Future<Map<String, double>> getCompletionRates({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    ProgressPeriodType periodType = ProgressPeriodType.daily,
  }) async {
    try {
      return await _progressService.getCompletionRates(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
        periodType: periodType,
      );
    } catch (e) {
      print('Error getting completion rates: $e');
      return {};
    }
  }
  // All client-side scheduler methods removed as backend handles them now

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }
}

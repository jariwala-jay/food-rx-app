import 'package:flutter/material.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';
import '../models/tracker_goal.dart';
import '../models/tracker_progress.dart';
import 'tracker_progress_service.dart';
import 'tracker_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class TrackerService {
  final TrackerProgressService _progressService;
  final TrackerApiService _trackerApi = TrackerApiService();
  static final TrackerService _instance = TrackerService._internal();

  List<TrackerGoal> _cachedDailyTrackers = [];
  List<TrackerGoal> _cachedWeeklyTrackers = [];
  bool _useLocalFallback = false;
  bool _isInitialized = false;

  factory TrackerService() => _instance;

  TrackerService._internal() : _progressService = TrackerProgressService();

  Future<void> _ensureMongoConnection() async {
    try {
      _isInitialized = true;
      _useLocalFallback = false;
    } catch (e) {
      print('Tracker API fallback: $e');
      _useLocalFallback = true;
      _isInitialized = false;
    }
  }

  // Queue of pending tracker updates to MongoDB - now using a different approach
  final List<Map<String, dynamic>> _pendingUpdates = [];
  final bool _isProcessingQueue = false;
  final Completer<void>? _processingCompleter = null;

  // Clear all tracker cache for a user (useful when diet type changes)
  Future<void> clearUserTrackerCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get all keys and find ones that match this user
      final allKeys = prefs.getKeys();
      final userTrackerKeys = allKeys
          .where((key) =>
              key.startsWith('daily_trackers_${userId}_') ||
              key.startsWith('weekly_trackers_${userId}_'))
          .toList();

      // Remove all user tracker cache entries
      for (final key in userTrackerKeys) {
        await prefs.remove(key);
      }

      // Clear memory cache
      _cachedDailyTrackers = [];
      _cachedWeeklyTrackers = [];

      print('Cleared all tracker cache for user: $userId');
    } catch (e) {
      print('Failed to clear tracker cache: $e');
    }
  }

  /// Clear cache only for one diet type. Use when reinitializing or fixing
  /// trackers for that type so the other diet type's cache is preserved.
  Future<void> clearUserTrackerCacheForDietType(
      String userId, String dietType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dailyKey = 'daily_trackers_${userId}_$dietType';
      final weeklyKey = 'weekly_trackers_${userId}_$dietType';
      await prefs.remove(dailyKey);
      await prefs.remove(weeklyKey);

      final currentDiet = _cachedDailyTrackers.isNotEmpty
          ? _cachedDailyTrackers.first.dietType
          : (_cachedWeeklyTrackers.isNotEmpty
              ? _cachedWeeklyTrackers.first.dietType
              : null);
      if (currentDiet != null &&
          currentDiet.toLowerCase() == dietType.toLowerCase()) {
        _cachedDailyTrackers = [];
        _cachedWeeklyTrackers = [];
      }
    } catch (e) {
      print('Failed to clear tracker cache for dietType $dietType: $e');
    }
  }

  // Cache trackers locally
  Future<void> _cacheTrackersLocally(List<TrackerGoal> daily,
      List<TrackerGoal> weekly, String userId, String dietType) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Only clear cache if diet type has changed (don't clear on every cache operation)
      // This prevents race conditions when multiple operations happen concurrently
      final dailyCacheKey = 'daily_trackers_${userId}_$dietType';
      final weeklyCacheKey = 'weekly_trackers_${userId}_$dietType';

      // Check if we're caching a different diet type than what's currently cached
      bool shouldClearCache = false;
      String? previousDietType;
      if (_cachedDailyTrackers.isNotEmpty || _cachedWeeklyTrackers.isNotEmpty) {
        previousDietType = _cachedDailyTrackers.isNotEmpty
            ? _cachedDailyTrackers.first.dietType
            : _cachedWeeklyTrackers.first.dietType;
        if (previousDietType != dietType) {
          shouldClearCache = true;
        }
      }

      // Only clear the previous diet type's cache (preserve other diet types)
      if (shouldClearCache && previousDietType != null) {
        print('🧹 Clearing cache for previous diet type: $previousDietType');
        await clearUserTrackerCacheForDietType(userId, previousDietType);
      }

      // Save to shared preferences
      await prefs.setString(
          dailyCacheKey, jsonEncode(daily.map((t) => t.toJson()).toList()));
      await prefs.setString(
          weeklyCacheKey, jsonEncode(weekly.map((t) => t.toJson()).toList()));

      // Update memory cache
      _cachedDailyTrackers = List.from(daily);
      _cachedWeeklyTrackers = List.from(weekly);

      print(
          '💾 Cached ${daily.length} daily and ${weekly.length} weekly trackers for dietType: $dietType');
    } catch (e) {
      print('Failed to cache trackers locally: $e');
    }
  }

  // Retrieve trackers from local cache
  Future<List<TrackerGoal>> _getLocalTrackers(
      String userId, String dietType, bool isWeekly) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = isWeekly
          ? 'weekly_trackers_${userId}_$dietType'
          : 'daily_trackers_${userId}_$dietType';

      // Try to get from memory cache first, but verify diet type matches
      if (isWeekly && _cachedWeeklyTrackers.isNotEmpty) {
        final cached = _cachedWeeklyTrackers;
        if (cached.first.dietType == dietType) {
          return List.from(cached);
        }
        // Clear cache if diet type doesn't match
        _cachedWeeklyTrackers = [];
      } else if (!isWeekly && _cachedDailyTrackers.isNotEmpty) {
        final cached = _cachedDailyTrackers;
        if (cached.first.dietType == dietType) {
          return List.from(cached);
        }
        // Clear cache if diet type doesn't match
        _cachedDailyTrackers = [];
      }

      // Otherwise load from shared preferences
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final List<dynamic> decoded = jsonDecode(cached);
        final trackers =
            decoded.map((json) => TrackerGoal.fromJson(json)).toList();

        // Verify all trackers match the requested diet type
        if (trackers.isNotEmpty && trackers.first.dietType == dietType) {
          // Update memory cache
          if (isWeekly) {
            _cachedWeeklyTrackers = List.from(trackers);
          } else {
            _cachedDailyTrackers = List.from(trackers);
          }
          return trackers;
        } else {
          // If diet type doesn't match, clear this cache entry
          await prefs.remove(cacheKey);
        }
      }

      // If not in cache, return empty list
      return [];
    } catch (e) {
      print('Failed to get local trackers: $e');
      return [];
    }
  }

  // Fetch all trackers for a specific user and diet type
  Future<List<TrackerGoal>> getTrackers(String userId, String dietType) async {
    try {
      await _ensureMongoConnection();

      if (_useLocalFallback) {
        final dailyTrackers = await _getLocalTrackers(userId, dietType, false);
        final weeklyTrackers = await _getLocalTrackers(userId, dietType, true);
        return [...dailyTrackers, ...weeklyTrackers];
      }

      final trackers =
          await _trackerApi.getTrackers(userId, dietType: dietType);

      // Update cache
      final dailyTrackers = trackers.where((t) => !t.isWeeklyGoal).toList();
      final weeklyTrackers = trackers.where((t) => t.isWeeklyGoal).toList();
      await _cacheTrackersLocally(
          dailyTrackers, weeklyTrackers, userId, dietType);

      return trackers;
    } catch (e) {
      print('Error fetching trackers from MongoDB: $e');
      return await _getFallbackTrackers(userId, dietType);
    }
  }

  // Fallback method to get trackers from local cache
  Future<List<TrackerGoal>> _getFallbackTrackers(
      String userId, String dietType) async {
    final dailyTrackers = await _getLocalTrackers(userId, dietType, false);
    final weeklyTrackers = await _getLocalTrackers(userId, dietType, true);
    return [...dailyTrackers, ...weeklyTrackers];
  }

  // Initialize default trackers for a new user
  Future<void> initializeUserTrackers(String userId, String dietType,
      {Map<String, dynamic>? personalizedDietPlan}) async {
    try {
      await _ensureMongoConnection();

      // Create default trackers
      final defaultTrackers = _getDefaultTrackers(userId, dietType,
          personalizedDietPlan: personalizedDietPlan);

      if (_useLocalFallback) {
        // Save default trackers locally
        final dailyTrackers =
            defaultTrackers.where((t) => !t.isWeeklyGoal).toList();
        final weeklyTrackers =
            defaultTrackers.where((t) => t.isWeeklyGoal).toList();
        await _cacheTrackersLocally(
            dailyTrackers, weeklyTrackers, userId, dietType);
        return;
      }

      // Check if trackers already exist for this specific diet type
      final existingTrackers =
          await _trackerApi.getTrackers(userId, dietType: dietType);
      final expectedCount = defaultTrackers.length;
      final hasCompleteSet = existingTrackers.length >= expectedCount;

      if (existingTrackers.isNotEmpty && hasCompleteSet) {
        final dailyTrackers =
            existingTrackers.where((t) => !t.isWeeklyGoal).toList();
        final weeklyTrackers =
            existingTrackers.where((t) => t.isWeeklyGoal).toList();
        await _cacheTrackersLocally(
            dailyTrackers, weeklyTrackers, userId, dietType);
        return;
      }

      // Incomplete or no trackers: replace with full set for this diet type
      if (existingTrackers.isNotEmpty) {
        for (final t in existingTrackers) {
          try {
            await _trackerApi.deleteTracker(t.id);
          } catch (_) {}
        }
      }

      // Insert new trackers for this diet type only.
      // Do NOT delete other diet types' trackers - DASH and MyPlate each
      // keep their own values when switching between plans.
      await _insertTrackersToMongoDB(defaultTrackers, userId, dietType);
    } catch (e) {
      print('Error initializing trackers: $e');
      await _initializeLocalTrackers(
          userId,
          dietType,
          _getDefaultTrackers(userId, dietType,
              personalizedDietPlan: personalizedDietPlan));
    }
  }

  // Initialize trackers locally only
  Future<void> _initializeLocalTrackers(
      String userId, String dietType, List<TrackerGoal> defaultTrackers) async {
    final dailyTrackers =
        defaultTrackers.where((t) => !t.isWeeklyGoal).toList();
    final weeklyTrackers =
        defaultTrackers.where((t) => t.isWeeklyGoal).toList();
    await _cacheTrackersLocally(
        dailyTrackers, weeklyTrackers, userId, dietType);
  }

  /// Updates only goal values from the personalized plan for existing trackers.
  /// Preserves currentValue so today's progress is not lost when switching plans.
  Future<void> updateTrackerGoalsFromPlan(List<TrackerGoal> existingTrackers,
      String dietType, Map<String, dynamic> personalizedDietPlan) async {
    if (existingTrackers.isEmpty) return;
    try {
      await _ensureMongoConnection();
      if (_useLocalFallback) return;

      for (final t in existingTrackers) {
        final categoryName = t.category.name.toLowerCase();
        double? newGoal;
        if (dietType.toLowerCase() == 'dash' ||
            dietType.toLowerCase() == 'diabetesplate') {
          if (categoryName == 'vegetables' || categoryName == 'veggies') {
            newGoal = _safeToDouble(personalizedDietPlan['vegetablesMax'], t.goalValue);
          } else if (categoryName == 'fruits') {
            newGoal = _safeToDouble(personalizedDietPlan['fruitsMax'], t.goalValue);
          } else if (categoryName == 'grains') {
            newGoal = _safeToDouble(personalizedDietPlan['grainsMax'], t.goalValue);
          } else if (categoryName == 'dairy') {
            newGoal = _safeToDouble(personalizedDietPlan['dairyMax'], t.goalValue);
          } else if (categoryName == 'leanmeat' || categoryName == 'protein') {
            newGoal = _safeToDouble(personalizedDietPlan['leanMeatsMax'], t.goalValue);
          } else if (categoryName == 'fatsoils') {
            newGoal = _safeToDouble(personalizedDietPlan['oilsMax'], t.goalValue);
          } else if (categoryName == 'water') {
            newGoal = _safeToDouble(personalizedDietPlan['waterCups'], t.goalValue);
          } else if (categoryName == 'sodium') {
            newGoal = _safeToDouble(
                personalizedDietPlan['sodium_mg_per_day_max'] ?? personalizedDietPlan['sodium'],
                t.goalValue);
          } else if (categoryName == 'sweets') {
            newGoal = _safeToDouble(personalizedDietPlan['sweetsMaxPerWeek'], t.goalValue);
          } else if (categoryName == 'nutslegumes') {
            newGoal = _safeToDouble(personalizedDietPlan['nutsLegumesPerWeek'], t.goalValue);
          }
        } else if (dietType.toLowerCase() == 'myplate') {
          if (categoryName == 'vegetables' || categoryName == 'veggies') {
            newGoal = _safeToDouble(personalizedDietPlan['vegetables'], t.goalValue);
          } else if (categoryName == 'fruits') {
            newGoal = _safeToDouble(personalizedDietPlan['fruits'], t.goalValue);
          } else if (categoryName == 'grains') {
            newGoal = _safeToDouble(personalizedDietPlan['grains'], t.goalValue);
          } else if (categoryName == 'protein') {
            newGoal = _safeToDouble(personalizedDietPlan['protein'], t.goalValue);
          } else if (categoryName == 'dairy') {
            newGoal = _safeToDouble(personalizedDietPlan['dairy'], t.goalValue);
          }
        }
        if (newGoal != null && (t.goalValue - newGoal).abs() > 0.01) {
          await _trackerApi.updateTracker(t.id, {'goalValue': newGoal});
        }
      }
    } catch (e) {
      print('Error updating tracker goals from plan: $e');
    }
  }

  // Update existing trackers with personalized values (full replace - use only when initializing)
  Future<void> updateTrackersWithPersonalizedPlan(String userId,
      String dietType, Map<String, dynamic> personalizedDietPlan) async {
    try {
      await _ensureMongoConnection();

      // Create new trackers with personalized values
      final personalizedTrackers = _getDefaultTrackers(userId, dietType,
          personalizedDietPlan: personalizedDietPlan);

      if (_useLocalFallback) {
        // Update local cache
        final dailyTrackers =
            personalizedTrackers.where((t) => !t.isWeeklyGoal).toList();
        final weeklyTrackers =
            personalizedTrackers.where((t) => t.isWeeklyGoal).toList();
        await _cacheTrackersLocally(
            dailyTrackers, weeklyTrackers, userId, dietType);
        return;
      }

      // Only replace trackers for THIS diet type (preserve other plan's trackers)
      final oldTrackersForPlan =
          await _trackerApi.getTrackers(userId, dietType: dietType);
      for (final t in oldTrackersForPlan) {
        try {
          await _trackerApi.deleteTracker(t.id);
        } catch (_) {}
      }
      await _insertTrackersToMongoDB(personalizedTrackers, userId, dietType);
    } catch (e) {
      print('Error updating trackers with personalized plan: $e');
      // Fallback to local update
      final personalizedTrackers = _getDefaultTrackers(userId, dietType,
          personalizedDietPlan: personalizedDietPlan);
      await _initializeLocalTrackers(userId, dietType, personalizedTrackers);
    }
  }

  Future<void> _insertTrackersToMongoDB(
      List<TrackerGoal> defaultTrackers, String userId, String dietType) async {
    List<TrackerGoal> createdTrackers = [];

    for (var tracker in defaultTrackers) {
      try {
        final json = {
          'userId': userId,
          'name': tracker.name,
          'category': tracker.category.toString().split('.').last,
          'goalValue': tracker.goalValue,
          'currentValue': tracker.currentValue,
          'unit': tracker.unit.toString().split('.').last,
          'colorStart': tracker.colorStart?.value,
          'colorEnd': tracker.colorEnd?.value,
          'dietType': tracker.dietType,
          'isWeeklyGoal': tracker.isWeeklyGoal,
          'lastUpdated': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        };

        final created = await _trackerApi.createTracker(json);
        createdTrackers.add(created);
      } catch (e) {
        print('Failed to insert tracker ${tracker.name}: $e');
      }
    }

    final dailyTrackers =
        createdTrackers.where((t) => !t.isWeeklyGoal).toList();
    final weeklyTrackers =
        createdTrackers.where((t) => t.isWeeklyGoal).toList();
    await _cacheTrackersLocally(
        dailyTrackers, weeklyTrackers, userId, dietType);
  }

  // Update a tracker's current value - improved approach
  Future<void> updateTrackerValue(String trackerId, double newValue) async {
    // 1. ALWAYS update the local cache first for immediate response
    await _updateTrackerInLocalCache(trackerId, newValue);

    // 2. Update MongoDB and ensure cache consistency
    try {
      await _ensureMongoConnection();
      if (!_useLocalFallback) {
        await _sendUpdateToMongoDB(trackerId, newValue);

        // 3. After successful MongoDB update, refresh the specific tracker from DB
        // to ensure cache consistency
        await _refreshTrackerFromMongoDB(trackerId);

        // 4. Trigger health goal notifications
        await _triggerHealthGoalNotifications(trackerId, newValue);
      }
    } catch (e) {
      print('MongoDB update failed, continuing with local cache: $e');
      _useLocalFallback = true;
    }
  }

  Future<void> _refreshTrackerFromMongoDB(String trackerId) async {
    try {
      final updatedTracker = await _trackerApi.getTracker(trackerId);
      if (updatedTracker != null) {
        await _updateSpecificTrackerInCache(updatedTracker);
      }
    } catch (e) {
      print('Failed to refresh tracker from API: $e');
    }
  }

  // Update a specific tracker in the cache
  Future<void> _updateSpecificTrackerInCache(TrackerGoal updatedTracker) async {
    try {
      bool updated = false;

      // Update in daily trackers
      for (int i = 0; i < _cachedDailyTrackers.length; i++) {
        if (_cachedDailyTrackers[i].id == updatedTracker.id) {
          _cachedDailyTrackers[i] = updatedTracker;
          updated = true;
          break;
        }
      }

      // Update in weekly trackers if not found in daily
      if (!updated) {
        for (int i = 0; i < _cachedWeeklyTrackers.length; i++) {
          if (_cachedWeeklyTrackers[i].id == updatedTracker.id) {
            _cachedWeeklyTrackers[i] = updatedTracker;
            updated = true;
            break;
          }
        }
      }

      if (updated) {
        await _persistCachedTrackers();
      }
    } catch (e) {
      print('Failed to update specific tracker in cache: $e');
    }
  }

  // Update tracker in local cache with better error handling
  Future<void> _updateTrackerInLocalCache(
      String trackerId, double newValue) async {
    try {
      String cleanId = trackerId;
      if (trackerId.startsWith('ObjectId("') && trackerId.endsWith('")')) {
        cleanId = trackerId.substring(9, trackerId.length - 2);
      }

      bool updated = false;

      // Create new lists to avoid concurrent modification
      List<TrackerGoal> updatedDailyTrackers = [];
      for (final tracker in _cachedDailyTrackers) {
        if (tracker.id == trackerId || tracker.id == cleanId) {
          updatedDailyTrackers.add(tracker.copyWith(
            currentValue: newValue,
            lastUpdated: DateTime.now(),
          ));
          updated = true;
        } else {
          updatedDailyTrackers.add(tracker);
        }
      }

      List<TrackerGoal> updatedWeeklyTrackers = [];
      if (!updated) {
        for (final tracker in _cachedWeeklyTrackers) {
          if (tracker.id == trackerId || tracker.id == cleanId) {
            updatedWeeklyTrackers.add(tracker.copyWith(
              currentValue: newValue,
              lastUpdated: DateTime.now(),
            ));
            updated = true;
          } else {
            updatedWeeklyTrackers.add(tracker);
          }
        }
      } else {
        updatedWeeklyTrackers = List.from(_cachedWeeklyTrackers);
      }

      if (updated) {
        _cachedDailyTrackers = updatedDailyTrackers;
        _cachedWeeklyTrackers = updatedWeeklyTrackers;
        await _persistCachedTrackers();
      }
    } catch (e) {
      print('Failed to update local cache: $e');
    }
  }

  // Persist cached trackers to shared preferences
  Future<void> _persistCachedTrackers() async {
    try {
      if (_cachedDailyTrackers.isEmpty && _cachedWeeklyTrackers.isEmpty) {
        return;
      }

      final userId = _cachedDailyTrackers.isNotEmpty
          ? _cachedDailyTrackers.first.userId
          : _cachedWeeklyTrackers.first.userId;

      final dietType = _cachedDailyTrackers.isNotEmpty
          ? _cachedDailyTrackers.first.dietType
          : _cachedWeeklyTrackers.first.dietType;

      await _cacheTrackersLocally(
          _cachedDailyTrackers, _cachedWeeklyTrackers, userId, dietType);
    } catch (e) {
      print('Failed to persist cached trackers: $e');
    }
  }

  // Get all weekly trackers
  Future<List<TrackerGoal>> getWeeklyTrackers(
      String userId, String dietType) async {
    try {
      await _ensureMongoConnection();

      if (_useLocalFallback) {
        return await _getLocalTrackers(userId, dietType, true);
      }

      final trackers = await _trackerApi.getTrackers(userId,
          dietType: dietType, isWeeklyGoal: true);

      // Update cache
      _cachedWeeklyTrackers = List.from(trackers);
      await _persistCachedTrackers();

      return trackers;
    } catch (e) {
      print('Error fetching weekly trackers: $e');
      return await _getLocalTrackers(userId, dietType, true);
    }
  }

  // Get all daily trackers
  Future<List<TrackerGoal>> getDailyTrackers(
      String userId, String dietType) async {
    try {
      await _ensureMongoConnection();

      if (_useLocalFallback) {
        return await _getLocalTrackers(userId, dietType, false);
      }

      final trackers = await _trackerApi.getTrackers(userId,
          dietType: dietType, isWeeklyGoal: false);

      // Update cache
      _cachedDailyTrackers = List.from(trackers);
      await _persistCachedTrackers();

      return trackers;
    } catch (e) {
      print('Error fetching daily trackers: $e');
      return await _getLocalTrackers(userId, dietType, false);
    }
  }

  // Reset daily trackers (e.g., at midnight)
  Future<void> resetDailyTrackers(String userId) async {
    try {
      // Get current daily trackers before resetting
      final currentTrackers = await getDailyTrackers(
          userId,
          _cachedDailyTrackers.isNotEmpty
              ? _cachedDailyTrackers.first.dietType
              : 'MyPlate');

      // Save progress snapshot for analytics (only if there's progress to save)
      if (currentTrackers.any((t) => t.currentValue > 0)) {
        await _progressService.saveProgressSnapshot(
            currentTrackers, ProgressPeriodType.daily);
      }

      // First reset in local cache
      await _resetTrackersInLocalCache(userId, false);

      if (!_useLocalFallback) {
        try {
          final daily =
              await _trackerApi.getTrackers(userId, isWeeklyGoal: false);
          for (final t in daily) {
            await _trackerApi.updateTracker(t.id, {
              'currentValue': 0.0,
              'lastUpdated': DateTime.now().toIso8601String()
            });
          }
        } catch (e) {
          print('Failed to reset daily trackers: $e');
        }
      }
    } catch (e) {
      print('Error resetting daily trackers: $e');
    }
  }

  // Reset weekly trackers (e.g., on Sunday midnight)
  Future<void> resetWeeklyTrackers(String userId) async {
    try {
      // Get current weekly trackers before resetting
      final currentTrackers = await getWeeklyTrackers(
          userId,
          _cachedWeeklyTrackers.isNotEmpty
              ? _cachedWeeklyTrackers.first.dietType
              : 'MyPlate');

      // Save progress snapshot for analytics (only if there's progress to save)
      if (currentTrackers.any((t) => t.currentValue > 0)) {
        await _progressService.saveProgressSnapshot(
            currentTrackers, ProgressPeriodType.weekly);
      }

      // First reset in local cache
      await _resetTrackersInLocalCache(userId, true);

      if (!_useLocalFallback) {
        try {
          final weekly =
              await _trackerApi.getTrackers(userId, isWeeklyGoal: true);
          for (final t in weekly) {
            await _trackerApi.updateTracker(t.id, {
              'currentValue': 0.0,
              'lastUpdated': DateTime.now().toIso8601String()
            });
          }
        } catch (e) {
          print('Failed to reset weekly trackers: $e');
        }
      }
    } catch (e) {
      print('Error resetting weekly trackers: $e');
    }
  }

  // Reset trackers in local cache
  Future<void> _resetTrackersInLocalCache(String userId, bool isWeekly) async {
    try {
      if (isWeekly) {
        List<TrackerGoal> resetTrackers = [];
        for (final tracker in _cachedWeeklyTrackers) {
          resetTrackers.add(tracker.copyWith(
            currentValue: 0.0,
            lastUpdated: DateTime.now(),
          ));
        }
        _cachedWeeklyTrackers = resetTrackers;
      } else {
        List<TrackerGoal> resetTrackers = [];
        for (final tracker in _cachedDailyTrackers) {
          resetTrackers.add(tracker.copyWith(
            currentValue: 0.0,
            lastUpdated: DateTime.now(),
          ));
        }
        _cachedDailyTrackers = resetTrackers;
      }

      await _persistCachedTrackers();
    } catch (e) {
      print('Failed to reset trackers in local cache: $e');
    }
  }

  // Cleanup duplicate trackers (MongoDB only)
  Future<void> cleanupDuplicateTrackers(String userId) async {
    try {
      await _ensureMongoConnection();
      if (_useLocalFallback) return;

      final trackers = await _trackerApi.getTrackers(userId);
      final list = trackers;
      Map<String, List<TrackerGoal>> groups = {};
      for (final t in list) {
        final key = '${t.name}_${t.isWeeklyGoal}';
        groups[key] ??= [];
        groups[key]!.add(t);
      }
      for (final group in groups.values) {
        if (group.length > 1) {
          group.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
          for (int i = 1; i < group.length; i++) {
            try {
              await _trackerApi.deleteTracker(group[i].id);
              print('Removed duplicate tracker: ${group[i].name}');
            } catch (e) {
              print('Failed to remove duplicate tracker: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error cleaning up duplicate trackers: $e');
    }
  }

  // Helper method to get default trackers based on diet type
  // Helper function to safely convert values to double
  // Handles both numeric and string types
  double _safeToDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? defaultValue;
    }
    try {
      return (value as num).toDouble();
    } catch (e) {
      return defaultValue;
    }
  }

  List<TrackerGoal> _getDefaultTrackers(String userId, String dietType,
      {Map<String, dynamic>? personalizedDietPlan}) {
    if (dietType == 'DASH' || dietType == 'DiabetesPlate') {
      return _getDefaultDashTrackers(userId,
          personalizedDietPlan: personalizedDietPlan,
          storeAsDietType: dietType);
    } else {
      // MyPlate trackers
      return _getDefaultMyPlateTrackers(userId, dietType,
          personalizedDietPlan: personalizedDietPlan);
    }
  }

  // Default trackers for DASH diet (and Diabetes Plate - same structure, different store key)
  List<TrackerGoal> _getDefaultDashTrackers(String userId,
      {Map<String, dynamic>? personalizedDietPlan, String storeAsDietType = 'DASH'}) {
    // Use personalized values if available, otherwise fall back to defaults
    final grains = _safeToDouble(personalizedDietPlan?['grainsMax'], 6.0);
    final vegetables =
        _safeToDouble(personalizedDietPlan?['vegetablesMax'], 4.0);
    final fruits = _safeToDouble(personalizedDietPlan?['fruitsMax'], 4.0);
    final dairy = _safeToDouble(personalizedDietPlan?['dairyMax'], 2.0);
    final leanMeats = _safeToDouble(personalizedDietPlan?['leanMeatsMax'], 6.0);
    final oils = _safeToDouble(personalizedDietPlan?['oilsMax'], 2.0);
    final nutsLegumes =
        _safeToDouble(personalizedDietPlan?['nutsLegumesPerWeek'], 4.0);
    final sweets =
        _safeToDouble(personalizedDietPlan?['sweetsMaxPerWeek'], 5.0);

    // Check if there are daily limits for sweets (2600+ kcal plans)
    final sweetsMaxPerDayValue = personalizedDietPlan?['sweetsMaxPerDay'];
    final sweetsMaxPerDay = sweetsMaxPerDayValue != null
        ? _safeToDouble(sweetsMaxPerDayValue, 0.0)
        : null;
    final hasDailySweets = sweetsMaxPerDay != null && sweetsMaxPerDay > 0;
    // Check both possible keys for sodium: 'sodium_mg_per_day_max' (from personalization) or 'sodium' (legacy)
    final sodium = _safeToDouble(
        personalizedDietPlan?['sodium_mg_per_day_max'] ??
            personalizedDietPlan?['sodium'],
        1500.0);

    return [
      TrackerGoal(
        userId: userId,
        name: 'Veggies',
        category: TrackerCategory.veggies,
        goalValue: vegetables,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFFFF6E6E),
        colorEnd: const Color(0xFFFF9797),
        dietType: storeAsDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Fruits',
        category: TrackerCategory.fruits,
        goalValue: fruits,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFFFF6E6E),
        colorEnd: const Color(0xFFFF9797),
        dietType: storeAsDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Protein',
        category: TrackerCategory.leanMeat,
        goalValue: leanMeats,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFFFFA726),
        colorEnd: const Color(0xFFFFCC80),
        dietType: storeAsDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Grains',
        category: TrackerCategory.grains,
        goalValue: grains,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFFFFA726),
        colorEnd: const Color(0xFFFFCC80),
        dietType: storeAsDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Dairy',
        category: TrackerCategory.dairy,
        goalValue: dairy,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFF4CAF50),
        colorEnd: const Color(0xFFA5D6A7),
        dietType: storeAsDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Fats/oils',
        category: TrackerCategory.fatsOils,
        goalValue: oils,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFF4CAF50),
        colorEnd: const Color(0xFFA5D6A7),
        dietType: storeAsDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Water',
        category: TrackerCategory.water,
        goalValue: 8.0,
        unit: TrackerUnit.cups,
        colorStart: const Color(0xFF2196F3),
        colorEnd: const Color(0xFF90CAF9),
        dietType: storeAsDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Sweets',
        category: TrackerCategory.sweets,
        goalValue: hasDailySweets ? sweetsMaxPerDay! : sweets,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFF4CAF50),
        colorEnd: const Color(0xFFA5D6A7),
        dietType: storeAsDietType,
        isWeeklyGoal: !hasDailySweets,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Nuts',
        category: TrackerCategory.nutsLegumes,
        goalValue: nutsLegumes,
        unit: TrackerUnit.servings,
        colorStart: const Color(0xFF4CAF50),
        colorEnd: const Color(0xFFA5D6A7),
        dietType: storeAsDietType,
        isWeeklyGoal: true,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Sodium',
        category: TrackerCategory.sodium,
        goalValue: sodium,
        unit: TrackerUnit.mg,
        colorStart: const Color(0xFFB0BEC5), // Blue Grey
        colorEnd: const Color(0xFF78909C),
        dietType: storeAsDietType,
        isWeeklyGoal: false,
      ),
    ];
  }

  // Default trackers for MyPlate diet (also used for DiabetesPlate)
  List<TrackerGoal> _getDefaultMyPlateTrackers(String userId, String dietType,
      {Map<String, dynamic>? personalizedDietPlan}) {
    // Use personalized values if available, otherwise fall back to defaults
    // Handle both numeric and string values safely
    final fruits = _safeToDouble(personalizedDietPlan?['fruits'], 2.0);
    final vegetables = _safeToDouble(personalizedDietPlan?['vegetables'], 2.5);
    final grains = _safeToDouble(personalizedDietPlan?['grains'], 6.0);
    final protein = _safeToDouble(personalizedDietPlan?['protein'], 5.5);
    final dairy = _safeToDouble(personalizedDietPlan?['dairy'], 3.0);
    // Check both possible keys for sodium: 'sodium_mg_per_day_max' (from personalization) or 'sodiumMax' (legacy)
    final sodium = _safeToDouble(
        personalizedDietPlan?['sodium_mg_per_day_max'] ??
            personalizedDietPlan?['sodiumMax'],
        2300.0);

    // Trackers always use "MyPlate" as dietType
    // Note: DiabetesPlate users should already be mapped to DASH before reaching here
    final trackerDietType = 'MyPlate';

    return [
      TrackerGoal(
        userId: userId,
        name: 'Veggies',
        category: TrackerCategory.veggies,
        goalValue: vegetables,
        unit: TrackerUnit.cups,
        colorStart: const Color(0xFFFF6E6E),
        colorEnd: const Color(0xFFFF9797),
        dietType: trackerDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Fruits',
        category: TrackerCategory.fruits,
        goalValue: fruits,
        unit: TrackerUnit.cups,
        colorStart: const Color(0xFFFF6E6E),
        colorEnd: const Color(0xFFFF9797),
        dietType: trackerDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Protein',
        category: TrackerCategory.protein,
        goalValue: protein,
        unit: TrackerUnit.oz,
        colorStart: const Color(0xFFFFA726),
        colorEnd: const Color(0xFFFFCC80),
        dietType: trackerDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Grains',
        category: TrackerCategory.grains,
        goalValue: grains,
        unit: TrackerUnit.oz,
        colorStart: const Color(0xFFFFA726),
        colorEnd: const Color(0xFFFFCC80),
        dietType: trackerDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Dairy',
        category: TrackerCategory.dairy,
        goalValue: dairy,
        unit: TrackerUnit.cups,
        colorStart: const Color(0xFF4CAF50),
        colorEnd: const Color(0xFFA5D6A7),
        dietType: trackerDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Water',
        category: TrackerCategory.water,
        goalValue: 8.0,
        unit: TrackerUnit.cups,
        colorStart: const Color(0xFF2196F3),
        colorEnd: const Color(0xFF90CAF9),
        dietType: trackerDietType,
      ),
      TrackerGoal(
        userId: userId,
        name: 'Sodium',
        category: TrackerCategory.sodium,
        goalValue: sodium,
        unit: TrackerUnit.mg,
        colorStart: const Color(0xFFB0BEC5),
        colorEnd: const Color(0xFF78909C),
        dietType: trackerDietType,
      ),
    ];
  }

  Future<void> _sendUpdateToMongoDB(String trackerId, double newValue) async {
    if (_useLocalFallback) return;
    try {
      await _trackerApi.updateTracker(trackerId, {
        'currentValue': newValue,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('API update failed for tracker $trackerId: $e');
      _useLocalFallback = true;
      rethrow;
    }
  }

  // Trigger health goal notifications when tracker values are updated
  Future<void> _triggerHealthGoalNotifications(
      String trackerId, double newValue) async {
    try {
      // Health goal notifications removed - simplified notification system
    } catch (e) {
      print('Error triggering health goal notifications: $e');
    }
  }
}

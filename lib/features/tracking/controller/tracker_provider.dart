// lib/features/tracking/controller/tracker_provider.dart

import 'package:flutter/material.dart';
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

  List<TrackerGoal> get dailyTrackers => _dailyTrackers;
  List<TrackerGoal> get weeklyTrackers => _weeklyTrackers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Add this clearError method
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> initializeUserTrackers(String userId, String dietType) async {
    _setError(null);
    _setLoading(true);
    try {
      // This call to _trackerService.initializeUserTrackers should handle provisioning
      // default trackers if none exist for the user on the backend.
      await _trackerService
          .initializeUserTrackers(userId, dietType)
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
        await initializeUserTrackers(userId, dietType);
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadUserTrackers(String userId, String dietType) async {
    _setError(null);
    _setLoading(true);
    try {
      // First try loading from local cache
      try {
        _dailyTrackers =
            await _trackerService.getDailyTrackers(userId, dietType);
        _weeklyTrackers =
            await _trackerService.getWeeklyTrackers(userId, dietType);

        // If we got trackers from the cache, use them
        if (_dailyTrackers.isNotEmpty || _weeklyTrackers.isNotEmpty) {
          _retryCount = 0;
          notifyListeners();
          // Try to sync with the database in the background
          _syncWithDatabase(
              userId, dietType); // Keep this for eventual consistency
          return;
        }
      } catch (localError) {
        print('Error loading from local cache: $localError');
        // Continue to try loading from the database
      }

      // Clean up duplicates if possible (non-critical, can run in background)
      try {
        await _trackerService.cleanupDuplicateTrackers(userId);
      } catch (e) {
        print('Warning: Failed to cleanup duplicate trackers: $e');
      }

      // Always attempt to fetch from MongoDB to get the latest state after backend resets
      try {
        _dailyTrackers =
            await _trackerService.getDailyTrackers(userId, dietType);
        _weeklyTrackers =
            await _trackerService.getWeeklyTrackers(userId, dietType);
      } catch (e) {
        throw Exception('Failed to load trackers from database: $e');
      }

      // If after all attempts, trackers are empty, re-initialize defaults
      // (This serves as a client-side fallback if backend provisioning fails for new users)
      if (_dailyTrackers.isEmpty && _weeklyTrackers.isEmpty) {
        await _initializeDefaultTrackers(userId, dietType);
      }

      _retryCount = 0;
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
  Future<void> _initializeDefaultTrackers(
      String userId, String dietType) async {
    final prefs = await SharedPreferences.getInstance();
    final initKey = 'tracker_init_${userId}';
    final alreadyInitializing = prefs.getBool(initKey) ?? false;

    if (!alreadyInitializing) {
      await prefs.setBool(initKey, true);

      try {
        await _trackerService
            .initializeUserTrackers(userId, dietType)
            .timeout(const Duration(seconds: 30));

        _dailyTrackers =
            await _trackerService.getDailyTrackers(userId, dietType);
        _weeklyTrackers =
            await _trackerService.getWeeklyTrackers(userId, dietType);
      } catch (e) {
        print('Error initializing trackers: $e');
      } finally {
        await prefs.remove(initKey);
      }
    } else {
      // Someone else is already initializing, wait and retry
      await Future.delayed(Duration(seconds: 3));
      try {
        _dailyTrackers =
            await _trackerService.getDailyTrackers(userId, dietType);
        _weeklyTrackers =
            await _trackerService.getWeeklyTrackers(userId, dietType);
      } catch (e) {
        print('Error loading trackers after waiting: $e');
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

        if (kDebugMode) {
          print(
              'TrackerProvider: Synced with database - updated ${updatedDailyTrackers.length} daily and ${updatedWeeklyTrackers.length} weekly trackers');
        }

        notifyListeners();
      }
    } catch (e) {
      print('Error syncing with database (non-critical): $e');
    }
  }

  Future<void> updateTrackerValue(String trackerId, double newValue) async {
    _setLoading(true);
    _setError(null);

    // Find the tracker before updating to avoid multiple UI refreshes
    final dailyIndex = _dailyTrackers.indexWhere((t) => t.id == trackerId);
    final weeklyIndex = _weeklyTrackers.indexWhere((t) => t.id == trackerId);

    try {
      // First update the database
      await _trackerService.updateTrackerValue(trackerId, newValue);

      // Only update local state if database update was successful
      bool updated = false;

      if (dailyIndex >= 0) {
        _dailyTrackers[dailyIndex] = _dailyTrackers[dailyIndex].copyWith(
          currentValue: newValue,
          lastUpdated: DateTime.now(),
        );
        updated = true;
      }

      if (weeklyIndex >= 0) {
        _weeklyTrackers[weeklyIndex] = _weeklyTrackers[weeklyIndex].copyWith(
          currentValue: newValue,
          lastUpdated: DateTime.now(),
        );
        updated = true;
      }

      if (updated) {
        // Only notify listeners once - avoid calling loadUserTrackers which refreshes everything
        notifyListeners();
      } else {
        // If we couldn't find the tracker locally, reload from database
        await _reloadSpecificTracker(trackerId);
      }
    } catch (e) {
      _setError('Failed to update tracker: $e');
      // Only reload the specific tracker that failed instead of all trackers
      await _reloadSpecificTracker(trackerId);
    } finally {
      _setLoading(false);
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
    await updateTrackerValue(trackerId, newValue);
  }

  Future<void> resetDailyTrackers(String userId) async {
    _setLoading(true);
    try {
      await _trackerService.resetDailyTrackers(userId);

      _dailyTrackers = _dailyTrackers
          .map((tracker) =>
              tracker.copyWith(currentValue: 0, lastUpdated: DateTime.now()))
          .toList();

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

      _weeklyTrackers = _weeklyTrackers
          .map((tracker) =>
              tracker.copyWith(currentValue: 0, lastUpdated: DateTime.now()))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to reset weekly trackers: $e');
    } finally {
      _setLoading(false);
    }
  }

  TrackerGoal? findTrackerById(String trackerId) {
    final dailyTracker =
        _dailyTrackers.where((t) => t.id == trackerId).firstOrNull;
    if (dailyTracker != null) return dailyTracker;

    return _weeklyTrackers.where((t) => t.id == trackerId).firstOrNull;
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

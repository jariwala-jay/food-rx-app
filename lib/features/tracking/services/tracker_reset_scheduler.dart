import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'tracker_service.dart';

class TrackerResetScheduler {
  static final TrackerResetScheduler _instance =
      TrackerResetScheduler._internal();
  factory TrackerResetScheduler() => _instance;
  TrackerResetScheduler._internal();

  final TrackerService _trackerService = TrackerService();
  Timer? _dailyTimer;
  Timer? _weeklyTimer;
  bool _isRunning = false;

  /// Start the automatic reset scheduler
  Future<void> startScheduler(String userId) async {
    if (_isRunning) return;

    _isRunning = true;
    await _scheduleDailyReset(userId);
    await _scheduleWeeklyReset(userId);

    print('Tracker reset scheduler started for user $userId');
  }

  /// Stop the scheduler
  void stopScheduler() {
    _dailyTimer?.cancel();
    _weeklyTimer?.cancel();
    _isRunning = false;
    print('Tracker reset scheduler stopped');
  }

  /// Schedule daily reset at midnight
  Future<void> _scheduleDailyReset(String userId) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);

    _dailyTimer = Timer(timeUntilMidnight, () async {
      await _performDailyReset(userId);
      // Schedule the next daily reset (24 hours from now)
      _dailyTimer = Timer.periodic(const Duration(days: 1), (_) async {
        await _performDailyReset(userId);
      });
    });

    print('Daily reset scheduled for $tomorrow');
  }

  /// Schedule weekly reset on Sunday at midnight
  Future<void> _scheduleWeeklyReset(String userId) async {
    final now = DateTime.now();
    final daysUntilSunday = (7 - now.weekday) % 7;
    final nextSunday = DateTime(now.year, now.month, now.day + daysUntilSunday);
    final timeUntilSunday = nextSunday.difference(now);

    _weeklyTimer = Timer(timeUntilSunday, () async {
      await _performWeeklyReset(userId);
      // Schedule the next weekly reset (7 days from now)
      _weeklyTimer = Timer.periodic(const Duration(days: 7), (_) async {
        await _performWeeklyReset(userId);
      });
    });

    print('Weekly reset scheduled for $nextSunday');
  }

  /// Perform daily reset with progress saving
  Future<void> _performDailyReset(String userId) async {
    try {
      print('Performing daily reset for user $userId at ${DateTime.now()}');

      // Check if we already reset today to avoid duplicate resets
      if (await _wasResetToday('daily_reset_$userId')) {
        print('Daily reset already performed today');
        return;
      }

      await _trackerService.resetDailyTrackers(userId);
      await _markResetComplete('daily_reset_$userId');

      print('Daily reset completed successfully');
    } catch (e) {
      print('Error during daily reset: $e');
    }
  }

  /// Perform weekly reset with progress saving
  Future<void> _performWeeklyReset(String userId) async {
    try {
      print('Performing weekly reset for user $userId at ${DateTime.now()}');

      // Check if we already reset this week to avoid duplicate resets
      if (await _wasResetThisWeek('weekly_reset_$userId')) {
        print('Weekly reset already performed this week');
        return;
      }

      await _trackerService.resetWeeklyTrackers(userId);
      await _markResetComplete('weekly_reset_$userId');

      print('Weekly reset completed successfully');
    } catch (e) {
      print('Error during weekly reset: $e');
    }
  }

  /// Check if reset was already performed today
  Future<bool> _wasResetToday(String resetKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastResetString = prefs.getString(resetKey);

      if (lastResetString == null) return false;

      final lastReset = DateTime.parse(lastResetString);
      final today = DateTime.now();

      // Check if last reset was today
      return lastReset.year == today.year &&
          lastReset.month == today.month &&
          lastReset.day == today.day;
    } catch (e) {
      print('Error checking reset status: $e');
      return false;
    }
  }

  /// Check if reset was already performed this week
  Future<bool> _wasResetThisWeek(String resetKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastResetString = prefs.getString(resetKey);

      if (lastResetString == null) return false;

      final lastReset = DateTime.parse(lastResetString);
      final now = DateTime.now();

      // Calculate the start of this week (Monday)
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekDate =
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      return lastReset.isAfter(startOfWeekDate);
    } catch (e) {
      print('Error checking weekly reset status: $e');
      return false;
    }
  }

  /// Mark reset as completed
  Future<void> _markResetComplete(String resetKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(resetKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error marking reset complete: $e');
    }
  }

  /// Manual reset methods for testing or immediate use
  Future<void> manualDailyReset(String userId) async {
    await _performDailyReset(userId);
  }

  Future<void> manualWeeklyReset(String userId) async {
    await _performWeeklyReset(userId);
  }

  /// Get next reset times for display purposes
  Map<String, DateTime> getNextResetTimes() {
    final now = DateTime.now();

    // Next daily reset (tomorrow at midnight)
    final nextDaily = DateTime(now.year, now.month, now.day + 1);

    // Next weekly reset (next Sunday at midnight)
    final daysUntilSunday = (7 - now.weekday) % 7;
    final nextWeekly = DateTime(now.year, now.month, now.day + daysUntilSunday);

    return {
      'daily': nextDaily,
      'weekly': nextWeekly,
    };
  }
}

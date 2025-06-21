import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import '../models/tracker_progress.dart';
import '../models/tracker_goal.dart';
import 'dart:async';

class TrackerProgressService {
  final MongoDBService _mongoDBService;
  static final TrackerProgressService _instance =
      TrackerProgressService._internal();

  // Singleton pattern
  factory TrackerProgressService() => _instance;
  TrackerProgressService._internal() : _mongoDBService = MongoDBService();

  // Collection name for progress history
  static const String _collectionName = 'tracker_progress';

  // Get DB collection with proper connection check
  Future<DbCollection?> get _collection async {
    try {
      await _ensureMongoConnection();
      return _mongoDBService.db.collection(_collectionName);
    } catch (e) {
      print('Failed to get progress collection: $e');
      return null;
    }
  }

  // Ensure MongoDB connection
  Future<void> _ensureMongoConnection() async {
    try {
      await _mongoDBService.ensureConnection();
    } catch (e) {
      throw Exception('MongoDB connection failed: $e');
    }
  }

  /// Save progress snapshot before resetting tracker goals
  Future<void> saveProgressSnapshot(
      List<TrackerGoal> trackers, ProgressPeriodType periodType) async {
    if (trackers.isEmpty) return;

    try {
      final collection = await _collection;
      if (collection == null) {
        print('Cannot save progress snapshot - MongoDB unavailable');
        return;
      }

      final now = DateTime.now();
      final progressDate = periodType == ProgressPeriodType.daily
          ? DateTime(now.year, now.month, now.day) // End of current day
          : _getWeekEndDate(now); // End of current week

      List<TrackerProgress> progressRecords = [];

      for (final tracker in trackers) {
        // Only save if there was some progress (avoid saving empty records)
        if (tracker.currentValue > 0) {
          final progress = TrackerProgress(
            userId: tracker.userId,
            trackerId: tracker.id,
            trackerName: tracker.name,
            trackerCategory: tracker.category.toString().split('.').last,
            targetValue: tracker.goalValue,
            achievedValue: tracker.currentValue,
            progressDate: progressDate,
            periodType: periodType,
            dietType: tracker.dietType,
            unit: tracker.unitString,
          );

          progressRecords.add(progress);
        }
      }

      // Batch insert all progress records
      if (progressRecords.isNotEmpty) {
        final documents = progressRecords
            .map((p) => {
                  '_id': ObjectId.fromHexString(p.id),
                  ...p.toJson()
                    ..remove('_id'), // Remove the string ID, use ObjectId
                })
            .toList();

        await collection.insertMany(documents);
        print(
            'Saved ${progressRecords.length} progress snapshots for ${periodType.name}');
      }
    } catch (e) {
      print('Error saving progress snapshot: $e');
    }
  }

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
      final collection = await _collection;
      if (collection == null) return [];

      // Build query
      final query = <String, dynamic>{'userId': userId};

      if (trackerId != null) {
        query['trackerId'] = trackerId;
      }

      if (periodType != null) {
        query['periodType'] = periodType.toString().split('.').last;
      }

      if (startDate != null || endDate != null) {
        query['progressDate'] = <String, dynamic>{};
        if (startDate != null) {
          query['progressDate']['\$gte'] = startDate.toIso8601String();
        }
        if (endDate != null) {
          query['progressDate']['\$lte'] = endDate.toIso8601String();
        }
      }

      // Execute query
      final results = await collection.find(query).toList();

      // Convert to TrackerProgress objects
      var progressList =
          results.map((doc) => TrackerProgress.fromJson(doc)).toList();

      // Sort by date (most recent first)
      progressList.sort((a, b) => b.progressDate.compareTo(a.progressDate));

      // Apply limit if specified
      if (limit != null && progressList.length > limit) {
        progressList = progressList.take(limit).toList();
      }

      return progressList;
    } catch (e) {
      print('Error getting progress history: $e');
      return [];
    }
  }

  /// Get weekly summary for a specific week
  Future<List<TrackerProgress>> getWeeklySummary(
      String userId, DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 6));

    return await getProgressHistory(
      userId: userId,
      periodType: ProgressPeriodType.daily,
      startDate: weekStart,
      endDate: weekEnd,
    );
  }

  /// Get monthly summary
  Future<List<TrackerProgress>> getMonthlySummary(
      String userId, DateTime month) async {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    return await getProgressHistory(
      userId: userId,
      startDate: monthStart,
      endDate: monthEnd,
    );
  }

  /// Calculate analytics for a tracker over a time period
  Future<TrackerAnalytics> getTrackerAnalytics({
    required String userId,
    required String trackerId,
    required DateTime startDate,
    required DateTime endDate,
    ProgressPeriodType periodType = ProgressPeriodType.daily,
  }) async {
    final progressHistory = await getProgressHistory(
      userId: userId,
      trackerId: trackerId,
      periodType: periodType,
      startDate: startDate,
      endDate: endDate,
    );

    return TrackerAnalytics.fromProgressHistory(
        progressHistory, startDate, endDate);
  }

  /// Get completion rates for all trackers in a time period
  Future<Map<String, double>> getCompletionRates({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    ProgressPeriodType periodType = ProgressPeriodType.daily,
  }) async {
    final progressHistory = await getProgressHistory(
      userId: userId,
      periodType: periodType,
      startDate: startDate,
      endDate: endDate,
    );

    final Map<String, List<TrackerProgress>> groupedByTracker = {};
    for (final progress in progressHistory) {
      groupedByTracker[progress.trackerName] ??= [];
      groupedByTracker[progress.trackerName]!.add(progress);
    }

    final Map<String, double> completionRates = {};
    for (final entry in groupedByTracker.entries) {
      final trackerName = entry.key;
      final progressList = entry.value;
      final completedCount = progressList.where((p) => p.goalMet).length;
      final totalCount = progressList.length;

      completionRates[trackerName] =
          totalCount > 0 ? (completedCount / totalCount * 100) : 0.0;
    }

    return completionRates;
  }

  /// Clean up old progress data (optional, for data management)
  Future<void> cleanupOldProgress({
    required String userId,
    required DateTime olderThan,
  }) async {
    try {
      final collection = await _collection;
      if (collection == null) return;

      await collection.deleteMany({
        'userId': userId,
        'progressDate': {'\$lt': olderThan.toIso8601String()},
      });

      print(
          'Cleaned up progress data older than ${olderThan.toIso8601String()}');
    } catch (e) {
      print('Error cleaning up old progress: $e');
    }
  }

  /// Helper to get the end date of the current week (Sunday)
  DateTime _getWeekEndDate(DateTime date) {
    final daysUntilSunday = (7 - date.weekday) % 7;
    final sunday = date.add(Duration(days: daysUntilSunday));
    return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
  }
}

/// Analytics data for a specific tracker
class TrackerAnalytics {
  final String trackerId;
  final String trackerName;
  final int totalDays;
  final int completedDays;
  final double averageCompletion;
  final double bestCompletion;
  final double completionRate;
  final int currentStreak;
  final int longestStreak;
  final DateTime startDate;
  final DateTime endDate;

  TrackerAnalytics({
    required this.trackerId,
    required this.trackerName,
    required this.totalDays,
    required this.completedDays,
    required this.averageCompletion,
    required this.bestCompletion,
    required this.completionRate,
    required this.currentStreak,
    required this.longestStreak,
    required this.startDate,
    required this.endDate,
  });

  factory TrackerAnalytics.fromProgressHistory(
    List<TrackerProgress> progressHistory,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (progressHistory.isEmpty) {
      return TrackerAnalytics(
        trackerId: '',
        trackerName: '',
        totalDays: 0,
        completedDays: 0,
        averageCompletion: 0.0,
        bestCompletion: 0.0,
        completionRate: 0.0,
        currentStreak: 0,
        longestStreak: 0,
        startDate: startDate,
        endDate: endDate,
      );
    }

    // Sort by date ascending for streak calculation
    progressHistory.sort((a, b) => a.progressDate.compareTo(b.progressDate));

    final trackerId = progressHistory.first.trackerId;
    final trackerName = progressHistory.first.trackerName;
    final totalDays = progressHistory.length;
    final completedDays = progressHistory.where((p) => p.goalMet).length;

    final averageCompletion = progressHistory.isNotEmpty
        ? progressHistory
                .map((p) => p.completionPercentage)
                .reduce((a, b) => a + b) /
            progressHistory.length
        : 0.0;

    final bestCompletion = progressHistory.isNotEmpty
        ? progressHistory
            .map((p) => p.completionPercentage)
            .reduce((a, b) => a > b ? a : b)
        : 0.0;

    final completionRate =
        totalDays > 0 ? (completedDays / totalDays * 100) : 0.0;

    // Calculate streaks
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;

    for (int i = progressHistory.length - 1; i >= 0; i--) {
      if (progressHistory[i].goalMet) {
        tempStreak++;
        if (i == progressHistory.length - 1) {
          currentStreak = tempStreak;
        }
      } else {
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
        tempStreak = 0;
        if (i == progressHistory.length - 1) {
          currentStreak = 0;
        }
      }
    }

    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }

    return TrackerAnalytics(
      trackerId: trackerId,
      trackerName: trackerName,
      totalDays: totalDays,
      completedDays: completedDays,
      averageCompletion: averageCompletion,
      bestCompletion: bestCompletion,
      completionRate: completionRate,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  String toString() {
    return 'TrackerAnalytics($trackerName: ${completionRate.toStringAsFixed(1)}% completion, ${currentStreak} day streak)';
  }
}

import 'package:flutter_app/features/tracking/services/tracker_api_service.dart';
import '../models/tracker_progress.dart';
import '../models/tracker_goal.dart';
import 'dart:async';

class TrackerProgressService {
  final TrackerApiService _api = TrackerApiService();
  static final TrackerProgressService _instance =
      TrackerProgressService._internal();

  factory TrackerProgressService() => _instance;
  TrackerProgressService._internal();

  /// Save progress snapshot before resetting tracker goals
  Future<void> saveProgressSnapshot(
      List<TrackerGoal> trackers, ProgressPeriodType periodType) async {
    if (trackers.isEmpty) return;

    try {
      final now = DateTime.now();
      final progressDate = periodType == ProgressPeriodType.daily
          ? DateTime(now.year, now.month, now.day)
          : _getWeekEndDate(now);

      List<Map<String, dynamic>> docs = [];

      for (final tracker in trackers) {
        if (tracker.currentValue > 0) {
          final p = TrackerProgress(
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
          final json = p.toJson();
          json.remove('_id');
          docs.add(json);
        }
      }

      if (docs.isNotEmpty) {
        await _api.saveProgress(docs);
        print(
            'Saved ${docs.length} progress snapshots for ${periodType.name}');
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
      var progressList = await _api.getProgress(
        trackerId: trackerId,
        periodType: periodType?.toString().split('.').last,
      );

      if (startDate != null || endDate != null) {
        progressList = progressList.where((p) {
          if (startDate != null && p.progressDate.isBefore(startDate)) return false;
          if (endDate != null && p.progressDate.isAfter(endDate)) return false;
          return true;
        }).toList();
      }

      progressList.sort((a, b) => b.progressDate.compareTo(a.progressDate));

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

  /// Clean up old progress data (optional, for data management).
  /// Backend does not yet support bulk delete by date; no-op for now.
  Future<void> cleanupOldProgress({
    required String userId,
    required DateTime olderThan,
  }) async {
    // TODO: add DELETE /trackers/progress?olderThan=... on backend if needed
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
    return 'TrackerAnalytics($trackerName: ${completionRate.toStringAsFixed(1)}% completion, $currentStreak day streak)';
  }
}

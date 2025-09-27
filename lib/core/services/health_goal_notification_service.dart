import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/features/tracking/models/tracker_progress.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/services/notification_trigger_service.dart';

class HealthGoalNotificationService {
  final MongoDBService _mongoDBService = MongoDBService();
  final NotificationTriggerService _triggerService = NotificationTriggerService();

  /// Check for daily progress milestones and create notifications
  Future<void> checkDailyProgressMilestones(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      // Get today's progress
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      // Get user's tracker goals
      final trackerGoals = await _getUserTrackerGoals(userId);
      
      // Get today's progress for each tracker
      for (final goal in trackerGoals) {
        final progress = await _getTodayProgress(userId, goal.id, startOfDay, endOfDay);
        
        if (progress != null) {
          await _checkProgressMilestones(userId, goal, progress);
        }
      }
      
    } catch (e) {
      debugPrint('Error checking daily progress milestones: $e');
    }
  }

  /// Check for streak achievements
  Future<void> checkStreakAchievements(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      // Get user's tracker goals
      final trackerGoals = await _getUserTrackerGoals(userId);
      
      for (final goal in trackerGoals) {
        final streak = await _calculateStreak(userId, goal.id);
        
        if (streak > 0) {
          await _checkStreakMilestones(userId, goal, streak);
        }
      }
      
    } catch (e) {
      debugPrint('Error checking streak achievements: $e');
    }
  }

  /// Check for weekly progress summaries
  Future<void> checkWeeklyProgressSummary(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      final now = DateTime.now();
      final weekStart = _getWeekStart(now);
      final weekEnd = weekStart.add(const Duration(days: 7));
      
      // Get weekly progress for all trackers
      final weeklyProgress = await _getWeeklyProgress(userId, weekStart, weekEnd);
      
      if (weeklyProgress.isNotEmpty) {
        await _createWeeklySummaryNotification(userId, weeklyProgress);
      }
      
    } catch (e) {
      debugPrint('Error checking weekly progress summary: $e');
    }
  }

  /// Check for goal completion celebrations
  Future<void> checkGoalCompletions(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      // Get user's tracker goals
      final trackerGoals = await _getUserTrackerGoals(userId);
      
      for (final goal in trackerGoals) {
        final progress = await _getTodayProgress(userId, goal.id, startOfDay, endOfDay);
        
        if (progress != null && progress.goalMet) {
          await _createGoalCompletionNotification(userId, goal, progress);
        }
      }
      
    } catch (e) {
      debugPrint('Error checking goal completions: $e');
    }
  }

  /// Check for motivation and encouragement notifications
  Future<void> checkMotivationNotifications(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      // Get user's recent performance
      final recentPerformance = await _getRecentPerformance(userId, 7); // Last 7 days
      
      if (recentPerformance.isNotEmpty) {
        await _createMotivationNotification(userId, recentPerformance);
      }
      
    } catch (e) {
      debugPrint('Error checking motivation notifications: $e');
    }
  }

  /// Check for goal adjustment suggestions
  Future<void> checkGoalAdjustmentSuggestions(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      // Get user's tracker goals
      final trackerGoals = await _getUserTrackerGoals(userId);
      
      for (final goal in trackerGoals) {
        final recentPerformance = await _getTrackerRecentPerformance(userId, goal.id, 14); // Last 14 days
        
        if (recentPerformance.isNotEmpty) {
          await _checkGoalAdjustmentNeeds(userId, goal, recentPerformance);
        }
      }
      
    } catch (e) {
      debugPrint('Error checking goal adjustment suggestions: $e');
    }
  }

  // Private helper methods

  Future<List<TrackerGoal>> _getUserTrackerGoals(String userId) async {
    try {
      final collection = _mongoDBService.db.collection('user_trackers');
      final results = await collection.find({
        'userId': userId,
        'isActive': true,
      }).toList();
      
      return results.map((doc) => TrackerGoal.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error getting user tracker goals: $e');
      return [];
    }
  }

  Future<TrackerProgress?> _getTodayProgress(String userId, String trackerId, DateTime startOfDay, DateTime endOfDay) async {
    try {
      final collection = _mongoDBService.db.collection('tracker_progress');
      final result = await collection.findOne({
        'userId': userId,
        'trackerId': trackerId,
        'progressDate': {
          '\$gte': startOfDay.toIso8601String(),
          '\$lt': endOfDay.toIso8601String(),
        },
        'periodType': 'daily',
      });
      
      if (result != null) {
        return TrackerProgress.fromJson(result);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting today progress: $e');
      return null;
    }
  }

  Future<List<TrackerProgress>> _getWeeklyProgress(String userId, DateTime weekStart, DateTime weekEnd) async {
    try {
      final collection = _mongoDBService.db.collection('tracker_progress');
      final results = await collection.find({
        'userId': userId,
        'progressDate': {
          '\$gte': weekStart.toIso8601String(),
          '\$lt': weekEnd.toIso8601String(),
        },
        'periodType': 'daily',
      }).toList();
      
      return results.map((doc) => TrackerProgress.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error getting weekly progress: $e');
      return [];
    }
  }

  Future<List<TrackerProgress>> _getRecentPerformance(String userId, int days) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));
      
      final collection = _mongoDBService.db.collection('tracker_progress');
      final results = await collection.find({
        'userId': userId,
        'progressDate': {
          '\$gte': startDate.toIso8601String(),
          '\$lte': endDate.toIso8601String(),
        },
        'periodType': 'daily',
      }).toList();
      
      return results.map((doc) => TrackerProgress.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error getting recent performance: $e');
      return [];
    }
  }

  Future<List<TrackerProgress>> _getTrackerRecentPerformance(String userId, String trackerId, int days) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));
      
      final collection = _mongoDBService.db.collection('tracker_progress');
      final results = await collection.find({
        'userId': userId,
        'trackerId': trackerId,
        'progressDate': {
          '\$gte': startDate.toIso8601String(),
          '\$lte': endDate.toIso8601String(),
        },
        'periodType': 'daily',
      }).toList();
      
      return results.map((doc) => TrackerProgress.fromJson(doc)).toList();
    } catch (e) {
      debugPrint('Error getting tracker recent performance: $e');
      return [];
    }
  }

  Future<int> _calculateStreak(String userId, String trackerId) async {
    try {
      final collection = _mongoDBService.db.collection('tracker_progress');
      
      // Get all daily progress for this tracker, ordered by date descending
      final results = await collection.find({
        'userId': userId,
        'trackerId': trackerId,
        'periodType': 'daily',
        'goalMet': true,
      }).toList();
      
      // Sort by progressDate descending
      results.sort((a, b) => DateTime.parse(b['progressDate']).compareTo(DateTime.parse(a['progressDate'])));
      
      if (results.isEmpty) return 0;
      
      int streak = 0;
      DateTime? lastDate;
      
      for (final doc in results) {
        final progressDate = DateTime.parse(doc['progressDate']);
        
        if (lastDate == null) {
          lastDate = progressDate;
          streak = 1;
        } else {
          final daysDifference = lastDate.difference(progressDate).inDays;
          if (daysDifference == 1) {
            streak++;
            lastDate = progressDate;
          } else {
            break;
          }
        }
      }
      
      return streak;
    } catch (e) {
      debugPrint('Error calculating streak: $e');
      return 0;
    }
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - weekday + 1);
  }

  // Notification creation methods

  Future<void> _checkProgressMilestones(String userId, TrackerGoal goal, TrackerProgress progress) async {
    final completionPercentage = progress.completionPercentage;
    
    // Check for milestone percentages
    if (completionPercentage >= 50 && completionPercentage < 75) {
      await _createProgressMilestoneNotification(userId, goal, progress, 50);
    } else if (completionPercentage >= 75 && completionPercentage < 90) {
      await _createProgressMilestoneNotification(userId, goal, progress, 75);
    } else if (completionPercentage >= 90 && completionPercentage < 100) {
      await _createProgressMilestoneNotification(userId, goal, progress, 90);
    }
  }

  Future<void> _checkStreakMilestones(String userId, TrackerGoal goal, int streak) async {
    // Check for streak milestones
    if (streak == 3) {
      await _createStreakNotification(userId, goal, streak, 'Getting Started!');
    } else if (streak == 7) {
      await _createStreakNotification(userId, goal, streak, 'One Week Strong!');
    } else if (streak == 14) {
      await _createStreakNotification(userId, goal, streak, 'Two Weeks!');
    } else if (streak == 30) {
      await _createStreakNotification(userId, goal, streak, 'One Month!');
    } else if (streak % 7 == 0 && streak > 30) {
      await _createStreakNotification(userId, goal, streak, 'Amazing Consistency!');
    }
  }

  Future<void> _checkGoalAdjustmentNeeds(String userId, TrackerGoal goal, List<TrackerProgress> recentPerformance) async {
    // Calculate average completion rate
    final totalCompletion = recentPerformance.fold(0.0, (sum, progress) => sum + progress.completionPercentage);
    final averageCompletion = totalCompletion / recentPerformance.length;
    
    // Suggest adjustments if consistently over or under achieving
    if (averageCompletion > 120) {
      await _createGoalAdjustmentNotification(userId, goal, 'increase', averageCompletion);
    } else if (averageCompletion < 60) {
      await _createGoalAdjustmentNotification(userId, goal, 'decrease', averageCompletion);
    }
  }

  Future<void> _createProgressMilestoneNotification(String userId, TrackerGoal goal, TrackerProgress progress, int milestone) async {
    await _triggerService.createNotification(
      userId: userId,
      type: NotificationType.healthGoal,
      category: NotificationCategory.dailyProgress,
      title: '$milestone% Complete! 🎯',
      message: 'Great progress on ${goal.name}! You\'re ${milestone}% of the way to your daily goal.',
      priority: NotificationPriority.medium,
      actionRequired: true,
      actionData: {
        'type': 'progress_milestone',
        'trackerId': goal.id,
        'trackerName': goal.name,
        'milestone': milestone,
        'completionPercentage': progress.completionPercentage,
      },
    );
  }

  Future<void> _createStreakNotification(String userId, TrackerGoal goal, int streak, String message) async {
    await _triggerService.createNotification(
      userId: userId,
      type: NotificationType.healthGoal,
      category: NotificationCategory.streak,
      title: '$message 🔥',
      message: 'You\'ve hit your ${goal.name} goal for $streak days in a row! Keep up the amazing work!',
      priority: NotificationPriority.high,
      actionRequired: true,
      actionData: {
        'type': 'streak_achievement',
        'trackerId': goal.id,
        'trackerName': goal.name,
        'streak': streak,
      },
    );
  }

  Future<void> _createGoalCompletionNotification(String userId, TrackerGoal goal, TrackerProgress progress) async {
    await _triggerService.createNotification(
      userId: userId,
      type: NotificationType.healthGoal,
      category: NotificationCategory.dailyProgress,
      title: 'Goal Achieved! 🎉',
      message: 'Congratulations! You\'ve completed your ${goal.name} goal for today!',
      priority: NotificationPriority.high,
      actionRequired: true,
      actionData: {
        'type': 'goal_completion',
        'trackerId': goal.id,
        'trackerName': goal.name,
        'achievedValue': progress.achievedValue,
        'targetValue': progress.targetValue,
      },
    );
  }

  Future<void> _createWeeklySummaryNotification(String userId, List<TrackerProgress> weeklyProgress) async {
    final completedGoals = weeklyProgress.where((p) => p.goalMet).length;
    final totalGoals = weeklyProgress.length;
    final completionRate = totalGoals > 0 ? (completedGoals / totalGoals * 100).round() : 0;
    
    String title;
    String message;
    
    if (completionRate >= 80) {
      title = 'Outstanding Week! 🌟';
      message = 'You completed $completedGoals out of $totalGoals goals this week! Amazing work!';
    } else if (completionRate >= 60) {
      title = 'Great Week! 👏';
      message = 'You completed $completedGoals out of $totalGoals goals this week. Keep it up!';
    } else {
      title = 'Weekly Summary 📊';
      message = 'You completed $completedGoals out of $totalGoals goals this week. Every step counts!';
    }
    
    await _triggerService.createNotification(
      userId: userId,
      type: NotificationType.healthGoal,
      category: NotificationCategory.dailyProgress,
      title: title,
      message: message,
      priority: NotificationPriority.medium,
      actionRequired: true,
      actionData: {
        'type': 'weekly_summary',
        'completedGoals': completedGoals,
        'totalGoals': totalGoals,
        'completionRate': completionRate,
      },
    );
  }

  Future<void> _createMotivationNotification(String userId, List<TrackerProgress> recentPerformance) async {
    final completedGoals = recentPerformance.where((p) => p.goalMet).length;
    final totalGoals = recentPerformance.length;
    final completionRate = totalGoals > 0 ? (completedGoals / totalGoals * 100).round() : 0;
    
    String title;
    String message;
    
    if (completionRate < 30) {
      title = 'You\'ve Got This! 💪';
      message = 'Every small step towards your health goals matters. Keep going!';
    } else if (completionRate < 60) {
      title = 'Making Progress! 📈';
      message = 'You\'re building great habits. Consistency is key!';
    } else {
      title = 'You\'re Crushing It! 🚀';
      message = 'Your dedication to your health goals is inspiring!';
    }
    
    await _triggerService.createNotification(
      userId: userId,
      type: NotificationType.healthGoal,
      category: NotificationCategory.motivation,
      title: title,
      message: message,
      priority: NotificationPriority.low,
      actionRequired: false,
      actionData: {
        'type': 'motivation',
        'completionRate': completionRate,
      },
    );
  }

  Future<void> _createGoalAdjustmentNotification(String userId, TrackerGoal goal, String adjustment, double averageCompletion) async {
    String title;
    String message;
    
    if (adjustment == 'increase') {
      title = 'Goal Too Easy? 📈';
      message = 'You\'re consistently exceeding your ${goal.name} goal. Consider increasing your target!';
    } else {
      title = 'Goal Too Challenging? 📉';
      message = 'Your ${goal.name} goal might be too ambitious. Consider adjusting it to be more achievable.';
    }
    
    await _triggerService.createNotification(
      userId: userId,
      type: NotificationType.healthGoal,
      category: NotificationCategory.goalAdjustment,
      title: title,
      message: message,
      priority: NotificationPriority.low,
      actionRequired: true,
      actionData: {
        'type': 'goal_adjustment',
        'trackerId': goal.id,
        'trackerName': goal.name,
        'adjustment': adjustment,
        'averageCompletion': averageCompletion,
      },
    );
  }
}

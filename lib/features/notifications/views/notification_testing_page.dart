import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/services/health_goal_notification_service.dart';
import 'package:flutter_app/core/services/notification_trigger_service.dart';
import 'package:flutter_app/core/services/pantry_notification_service.dart';
import 'package:flutter_app/core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationTestingPage extends StatefulWidget {
  const NotificationTestingPage({super.key});

  @override
  State<NotificationTestingPage> createState() =>
      _NotificationTestingPageState();
}

class _NotificationTestingPageState extends State<NotificationTestingPage> {
  String _testResults = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Testing'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Notification System Testing',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Health Goal Notifications
            _buildTestSection(
              'Health Goal Notifications',
              [
                _buildTestButton(
                    'Test Progress Milestones', _testProgressMilestones),
                _buildTestButton(
                    'Test Streak Achievements', _testStreakAchievements),
                _buildTestButton('Test Goal Completions', _testGoalCompletions),
                _buildTestButton('Test Motivation Notifications',
                    _testMotivationNotifications),
                _buildTestButton('Test Weekly Summary', _testWeeklySummary),
              ],
            ),

            const SizedBox(height: 20),

            // System Notifications
            _buildTestSection(
              'System Notifications',
              [
                _buildTestButton(
                    'Test Onboarding Status', _testOnboardingStatus),
                _buildTestButton('Test Re-engagement', _testReengagement),
                _buildTestButton('Test Meal Reminders', _testMealReminders),
                _buildTestButton('Test FCM Token', _testFCMToken),
              ],
            ),

            const SizedBox(height: 20),

            // Pantry Notifications
            _buildTestSection(
              'Pantry Notifications',
              [
                _buildTestButton(
                    'Test Expiration Alerts', _testExpirationAlerts),
                _buildTestButton('Test Low Stock Alerts', _testLowStockAlerts),
                _buildTestButton(
                    'Test Recipe Suggestions', _testRecipeSuggestions),
              ],
            ),

            const SizedBox(height: 20),

            // Notification Manager Tests
            _buildTestSection(
              'Notification Manager',
              [
                _buildTestButton('Load Notifications', _loadNotifications),
                _buildTestButton('Mark All as Read', _markAllAsRead),
                _buildTestButton(
                    'Clear All Notifications', _clearAllNotifications),
              ],
            ),

            const SizedBox(height: 20),

            // Results Display
            Container(
              height: 200, // Fixed height instead of Expanded
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _testResults.isEmpty
                      ? 'Test results will appear here...'
                      : _testResults,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Clear Results Button
            ElevatedButton(
              onPressed: _clearResults,
              child: const Text('Clear Results'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection(String title, List<Widget> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: buttons,
        ),
      ],
    );
  }

  Widget _buildTestButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 32), // Make buttons more compact
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12), // Smaller text
      ),
    );
  }

  void _addResult(String result) {
    setState(() {
      _testResults +=
          '${DateTime.now().toString().substring(11, 19)}: $result\n';
    });
  }

  void _clearResults() {
    setState(() {
      _testResults = '';
    });
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
  }

  // Health Goal Notification Tests
  Future<void> _testProgressMilestones() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userId = authController.currentUser?.id;

      if (userId == null) {
        _addResult('❌ No user logged in');
        return;
      }

      final healthGoalService = authController.healthGoalNotificationService;
      if (healthGoalService == null) {
        _addResult('❌ Health goal notification service not initialized');
        return;
      }

      await healthGoalService.checkDailyProgressMilestones(userId);
      _addResult('✅ Progress milestones check completed');
    } catch (e) {
      _addResult('❌ Error testing progress milestones: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _testStreakAchievements() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userId = authController.currentUser?.id;

      if (userId == null) {
        _addResult('❌ No user logged in');
        return;
      }

      final healthGoalService = authController.healthGoalNotificationService;
      if (healthGoalService == null) {
        _addResult('❌ Health goal notification service not initialized');
        return;
      }

      await healthGoalService.checkStreakAchievements(userId);
      _addResult('✅ Streak achievements check completed');
    } catch (e) {
      _addResult('❌ Error testing streak achievements: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _testGoalCompletions() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userId = authController.currentUser?.id;

      if (userId == null) {
        _addResult('❌ No user logged in');
        return;
      }

      final healthGoalService = authController.healthGoalNotificationService;
      if (healthGoalService == null) {
        _addResult('❌ Health goal notification service not initialized');
        return;
      }

      await healthGoalService.checkGoalCompletions(userId);
      _addResult('✅ Goal completions check completed');
    } catch (e) {
      _addResult('❌ Error testing goal completions: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _testMotivationNotifications() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userId = authController.currentUser?.id;

      if (userId == null) {
        _addResult('❌ No user logged in');
        return;
      }

      final healthGoalService = authController.healthGoalNotificationService;
      if (healthGoalService == null) {
        _addResult('❌ Health goal notification service not initialized');
        return;
      }

      await healthGoalService.checkMotivationNotifications(userId);
      _addResult('✅ Motivation notifications check completed');
    } catch (e) {
      _addResult('❌ Error testing motivation notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _testWeeklySummary() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userId = authController.currentUser?.id;

      if (userId == null) {
        _addResult('❌ No user logged in');
        return;
      }

      final healthGoalService = authController.healthGoalNotificationService;
      if (healthGoalService == null) {
        _addResult('❌ Health goal notification service not initialized');
        return;
      }

      await healthGoalService.checkWeeklyProgressSummary(userId);
      _addResult('✅ Weekly summary check completed');
    } catch (e) {
      _addResult('❌ Error testing weekly summary: $e');
    } finally {
      _setLoading(false);
    }
  }

  // System Notification Tests
  Future<void> _testOnboardingStatus() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userId = authController.currentUser?.id;

      if (userId == null) {
        _addResult('❌ No user logged in');
        return;
      }

      final triggerService = authController.notificationTriggerService;
      if (triggerService == null) {
        _addResult('❌ Notification trigger service not initialized');
        return;
      }

      await triggerService.checkOnboardingStatus(userId);
      _addResult('✅ Onboarding status check completed');
    } catch (e) {
      _addResult('❌ Error testing onboarding status: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _testReengagement() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userId = authController.currentUser?.id;

      if (userId == null) {
        _addResult('❌ No user logged in');
        return;
      }

      final triggerService = authController.notificationTriggerService;
      if (triggerService == null) {
        _addResult('❌ Notification trigger service not initialized');
        return;
      }

      await triggerService.checkReengagement(userId);
      _addResult('✅ Re-engagement check completed');
    } catch (e) {
      _addResult('❌ Error testing re-engagement: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _testMealReminders() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userId = authController.currentUser?.id;

      if (userId == null) {
        _addResult('❌ No user logged in');
        return;
      }

      final triggerService = authController.notificationTriggerService;
      if (triggerService == null) {
        _addResult('❌ Notification trigger service not initialized');
        return;
      }

      await triggerService.checkMealLoggingReminders(userId);
      _addResult('✅ Meal reminders check completed');
    } catch (e) {
      _addResult('❌ Error testing meal reminders: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Pantry Notification Tests
  Future<void> _testExpirationAlerts() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userId = authController.currentUser?.id;

      if (userId == null) {
        _addResult('❌ No user logged in');
        return;
      }

      final pantryService = PantryNotificationService();
      await pantryService.checkExpiringItems(userId);
      _addResult('✅ Expiration alerts check completed');
    } catch (e) {
      _addResult('❌ Error testing expiration alerts: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _testLowStockAlerts() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userId = authController.currentUser?.id;

      if (userId == null) {
        _addResult('❌ No user logged in');
        return;
      }

      final pantryService = PantryNotificationService();
      await pantryService.checkLowStock(userId);
      _addResult('✅ Low stock alerts check completed');
    } catch (e) {
      _addResult('❌ Error testing low stock alerts: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _testRecipeSuggestions() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userId = authController.currentUser?.id;

      if (userId == null) {
        _addResult('❌ No user logged in');
        return;
      }

      final pantryService = PantryNotificationService();
      await pantryService.suggestRecipesForExpiringItems(userId);
      _addResult('✅ Recipe suggestions check completed');
    } catch (e) {
      _addResult('❌ Error testing recipe suggestions: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Notification Manager Tests
  Future<void> _loadNotifications() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final notificationManager = authController.notificationManager;

      if (notificationManager == null) {
        _addResult('❌ Notification manager not initialized');
        return;
      }

      await notificationManager.loadNotifications();
      final count = notificationManager.notifications.length;
      final unreadCount = notificationManager.unreadCount;

      _addResult('✅ Loaded $count notifications ($unreadCount unread)');
    } catch (e) {
      _addResult('❌ Error loading notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _markAllAsRead() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final notificationManager = authController.notificationManager;

      if (notificationManager == null) {
        _addResult('❌ Notification manager not initialized');
        return;
      }

      await notificationManager.markAllAsRead();
      _addResult('✅ All notifications marked as read');
    } catch (e) {
      _addResult('❌ Error marking notifications as read: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _clearAllNotifications() async {
    _setLoading(true);
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final notificationManager = authController.notificationManager;

      if (notificationManager == null) {
        _addResult('❌ Notification manager not initialized');
        return;
      }

      await notificationManager.clearAllNotifications();
      _addResult('✅ All notifications cleared');
    } catch (e) {
      _addResult('❌ Error clearing notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  // FCM Token Test
  Future<void> _testFCMToken() async {
    _setLoading(true);
    _addResult('Testing FCM Token Generation...');

    try {
      final notificationService = NotificationService();
      await notificationService.initialize();

      // Get token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');
      final userId = prefs.getString('user_id');

      _addResult('User ID: $userId');
      _addResult('FCM Token: $token');

      if (token != null) {
        _addResult('✅ FCM Token found!');
      } else {
        _addResult('❌ No FCM Token found');
      }
    } catch (e) {
      _addResult('❌ Error: $e');
    } finally {
      _setLoading(false);
    }
  }
}

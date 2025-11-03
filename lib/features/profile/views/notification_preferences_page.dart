import 'package:flutter/material.dart';
import 'package:flutter_app/core/utils/typography.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  bool _expiringIngredientNotifications = true;
  bool _trackerReminderNotifications = true;
  bool _educationNotifications = true;
  bool _adminNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Notification Types',
                        style: AppTypography.bg_18_b,
                      ),
                    ),
                    _buildNotificationSwitch(
                      title: 'Expiring Ingredients',
                      subtitle:
                          'Get notified when pantry items are about to expire',
                      value: _expiringIngredientNotifications,
                      onChanged: (value) {
                        setState(() {
                          _expiringIngredientNotifications = value;
                        });
                        // TODO: Save preference
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNotificationSwitch(
                      title: 'Tracker Reminders',
                      subtitle: 'Receive reminders to log your daily trackers',
                      value: _trackerReminderNotifications,
                      onChanged: (value) {
                        setState(() {
                          _trackerReminderNotifications = value;
                        });
                        // TODO: Save preference
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNotificationSwitch(
                      title: 'Education Content',
                      subtitle:
                          'Get notified about new articles and health tips',
                      value: _educationNotifications,
                      onChanged: (value) {
                        setState(() {
                          _educationNotifications = value;
                        });
                        // TODO: Save preference
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNotificationSwitch(
                      title: 'Administrative Updates',
                      subtitle:
                          'Receive important app updates and announcements',
                      value: _adminNotifications,
                      onChanged: (value) {
                        setState(() {
                          _adminNotifications = value;
                        });
                        // TODO: Save preference
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Note',
                      style: AppTypography.bg_16_sb,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Notification preferences are saved automatically. Some notifications may still be sent for critical updates.',
                      style: AppTypography.bg_14_r.copyWith(
                        color: const Color(0xFF90909A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: AppTypography.bg_16_m),
      subtitle: Text(
        subtitle,
        style: AppTypography.bg_14_r.copyWith(
          color: const Color(0xFF90909A),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFFFF6A00),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
    );
  }
}

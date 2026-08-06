import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/services/notification_service.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';

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

  static const List<String> _mealOrder = ['breakfast', 'lunch', 'dinner'];
  static const Map<String, String> _mealLabels = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
  };
  static const Map<String, TimeOfDay> _defaultMealTimes = {
    'breakfast': TimeOfDay(hour: 9, minute: 0),
    'lunch': TimeOfDay(hour: 13, minute: 0),
    'dinner': TimeOfDay(hour: 20, minute: 0),
  };

  late bool _mealRemindersEnabled;
  late Map<String, TimeOfDay> _mealTimes;

  @override
  void initState() {
    super.initState();
    final prefs =
        context.read<AuthController>().currentUser?.mealLoggingReminderPrefs;
    _mealRemindersEnabled = prefs?['enabled'] == true;
    _mealTimes = {
      for (final meal in _mealOrder)
        meal: _timeOfDayFrom(prefs?[meal]) ?? _defaultMealTimes[meal]!,
    };
  }

  static TimeOfDay? _timeOfDayFrom(dynamic mealPrefs) {
    if (mealPrefs is Map &&
        mealPrefs['hour'] is int &&
        mealPrefs['minute'] is int) {
      return TimeOfDay(
        hour: mealPrefs['hour'] as int,
        minute: mealPrefs['minute'] as int,
      );
    }
    return null;
  }

  Map<String, dynamic> _buildMealPrefsPayload() {
    return {
      'enabled': _mealRemindersEnabled,
      for (final meal in _mealOrder)
        meal: {
          'hour': _mealTimes[meal]!.hour,
          'minute': _mealTimes[meal]!.minute
        },
    };
  }

  Future<void> _persistMealPrefs() async {
    final prefs = _buildMealPrefsPayload();
    await context
        .read<AuthController>()
        .updateUserProfile({'mealLoggingReminderPrefs': prefs});
    await NotificationService().applyMealLoggingReminderPreferences(prefs);
  }

  Future<void> _toggleMealReminders(bool value) async {
    setState(() => _mealRemindersEnabled = value);
    await _persistMealPrefs();
  }

  Future<void> _pickMealTime(String meal) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _mealTimes[meal]!,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFFFF6A00),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              dialBackgroundColor: const Color(0xFFF0F0F0),
              dialHandColor: const Color(0xFFFF6A00),
              entryModeIconColor: Colors.black54,
              helpTextStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              hourMinuteColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const Color(0xFFFF6A00)
                    : const Color(0xFFF0F0F0),
              ),
              hourMinuteTextColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.black,
              ),
              dayPeriodColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const Color(0xFFFF6A00)
                    : Colors.white,
              ),
              dayPeriodTextColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.black,
              ),
              dialTextColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _mealTimes[meal] = picked);
    await _persistMealPrefs();
  }

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
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNotificationSwitch(
                      title: 'Meal reminders',
                      subtitle:
                          'Receive reminders to log your breakfast, lunch and dinner',
                      value: _mealRemindersEnabled,
                      onChanged: (value) => _toggleMealReminders(value),
                    ),
                    if (_mealRemindersEnabled)
                      ..._mealOrder.map(
                        (meal) => _buildMealTimeRow(
                          title: _mealLabels[meal]!,
                          time: _mealTimes[meal]!,
                          onTap: () => _pickMealTime(meal),
                        ),
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

  Widget _buildMealTimeRow({
    required String title,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title, style: AppTypography.bg_16_m),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time.format(context),
            style: AppTypography.bg_14_r.copyWith(
              color: const Color(0xFF90909A),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Color(0xFF90909A)),
        ],
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
    );
  }
}

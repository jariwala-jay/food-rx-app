import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/services/notification_service.dart';
import 'package:flutter_app/core/utils/meal_reminder_prefs.dart';
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
  // Keys match the backend/Cloud Function `notificationTypePrefs` map —
  // see AuthController.updateUserProfile and notification_eligibility docs.
  static const String _expiringIngredientsKey = 'expiringIngredients';
  static const String _trackerRemindersKey = 'trackerReminders';
  static const String _educationKey = 'education';
  static const String _adminUpdatesKey = 'adminUpdates';

  late Map<String, bool> _notificationTypePrefs;

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

  late bool _mealRemindersMasterEnabled;
  late Map<String, bool> _mealEnabled;
  late Map<String, TimeOfDay> _mealTimes;

  @override
  void initState() {
    super.initState();
    final currentUser = context.read<AuthController>().currentUser;
    final prefs = currentUser?.mealLoggingReminderPrefs;
    _mealRemindersMasterEnabled = isMealRemindersMasterEnabled(prefs);
    _mealEnabled = {
      for (final meal in _mealOrder) meal: mealReminderOwnEnabled(prefs, meal),
    };
    // Self-heal stale data where the master was left on with every meal
    // individually off (e.g. saved before this sync existed) — the master
    // switch must never display as on when nothing underneath will fire.
    if (!_mealEnabled.values.any((enabled) => enabled)) {
      _mealRemindersMasterEnabled = false;
    }
    _mealTimes = {
      for (final meal in _mealOrder)
        meal: mealReminderTimeOfDay(prefs, meal, _defaultMealTimes[meal]!),
    };

    // Absent/non-bool => enabled, so existing accounts that never touched
    // these switches keep receiving everything they already get today.
    final typePrefs = currentUser?.notificationTypePrefs;
    bool enabledByDefault(String key) => typePrefs?[key] != false;
    _notificationTypePrefs = {
      _expiringIngredientsKey: enabledByDefault(_expiringIngredientsKey),
      _trackerRemindersKey: enabledByDefault(_trackerRemindersKey),
      _educationKey: enabledByDefault(_educationKey),
      _adminUpdatesKey: enabledByDefault(_adminUpdatesKey),
    };
  }

  Future<void> _toggleNotificationType(String key, bool value) async {
    setState(() => _notificationTypePrefs[key] = value);
    await context
        .read<AuthController>()
        .updateUserProfile({'notificationTypePrefs': _notificationTypePrefs});
  }

  Future<void> _persistMealPrefs() async {
    final prefs = buildMealReminderPrefsPayload(
      masterEnabled: _mealRemindersMasterEnabled,
      enabled: _mealEnabled,
      times: _mealTimes,
    );
    await context
        .read<AuthController>()
        .updateUserProfile({'mealLoggingReminderPrefs': prefs});
    await NotificationService().applyMealLoggingReminderPreferences(prefs);
  }

  Future<void> _toggleMasterEnabled(bool value) async {
    setState(() {
      _mealRemindersMasterEnabled = value;
      if (!value) {
        // Master off is a clean slate: every meal turns off and its time
        // resets to the default, so turning the master back on starts
        // fresh rather than silently resuming whatever was set before.
        for (final meal in _mealOrder) {
          _mealEnabled[meal] = false;
          _mealTimes[meal] = _defaultMealTimes[meal]!;
        }
      }
    });
    await _persistMealPrefs();
  }

  Future<void> _toggleMealEnabled(String meal, bool value) async {
    setState(() {
      _mealEnabled[meal] = value;
      // Turning off the last individually-enabled meal collapses the
      // master switch too — it must never show on when nothing underneath
      // will actually fire.
      if (!_mealEnabled.values.any((enabled) => enabled)) {
        _mealRemindersMasterEnabled = false;
      }
    });
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
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Notification Types',
                        style: AppTypography.bg_18_b,
                      ),
                    ),
                    _buildNotificationSwitch(
                      title: 'Expiring Ingredients',
                      subtitle:
                          'Get notified when pantry items are about to expire',
                      value: _notificationTypePrefs[_expiringIngredientsKey]!,
                      onChanged: (value) =>
                          _toggleNotificationType(_expiringIngredientsKey, value),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNotificationSwitch(
                      title: 'Tracker Reminders',
                      subtitle: 'Receive reminders to log your daily trackers',
                      value: _notificationTypePrefs[_trackerRemindersKey]!,
                      onChanged: (value) =>
                          _toggleNotificationType(_trackerRemindersKey, value),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNotificationSwitch(
                      title: 'Education Content',
                      subtitle:
                          'Get notified about new articles and health tips',
                      value: _notificationTypePrefs[_educationKey]!,
                      onChanged: (value) =>
                          _toggleNotificationType(_educationKey, value),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNotificationSwitch(
                      title: 'Administrative Updates',
                      subtitle:
                          'Receive important app updates and announcements',
                      value: _notificationTypePrefs[_adminUpdatesKey]!,
                      onChanged: (value) =>
                          _toggleNotificationType(_adminUpdatesKey, value),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNotificationSwitch(
                      title: 'Meal reminders',
                      subtitle:
                          'Receive reminders to log your breakfast, lunch and dinner',
                      value: _mealRemindersMasterEnabled,
                      onChanged: (value) => _toggleMasterEnabled(value),
                    ),
                    if (_mealRemindersMasterEnabled)
                      for (final meal in _mealOrder) ...[
                        _buildNotificationSwitch(
                          title: _mealLabels[meal]!,
                          subtitle:
                              'Get a reminder to log your ${_mealLabels[meal]!.toLowerCase()}',
                          value: _mealEnabled[meal]!,
                          onChanged: (value) =>
                              _toggleMealEnabled(meal, value),
                        ),
                        if (_mealEnabled[meal]!)
                          _buildMealTimeRow(
                            time: _mealTimes[meal]!,
                            onTap: () => _pickMealTime(meal),
                          ),
                      ],
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
                    const Text(
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
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        time.format(context),
        style: AppTypography.bg_14_r.copyWith(
          color: const Color(0xFF90909A),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF90909A)),
      onTap: onTap,
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
    );
  }
}

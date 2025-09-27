import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/core/models/notification_preferences.dart';
import 'package:flutter_app/core/services/notification_manager.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  NotificationPreferences? _preferences;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final notificationManager =
        Provider.of<NotificationManager>(context, listen: false);
    setState(() {
      _preferences = notificationManager.preferences;
    });
  }

  Future<void> _updatePreferences() async {
    if (_preferences == null) return;

    setState(() {
      _isLoading = true;
    });

    final notificationManager =
        Provider.of<NotificationManager>(context, listen: false);
    final success = await notificationManager.updatePreferences(_preferences!);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification preferences updated')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update preferences')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _preferences == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationTypesSection(),
                  const SizedBox(height: 24),
                  _buildTimingSection(),
                  const SizedBox(height: 24),
                  _buildFrequencySection(),
                  const SizedBox(height: 24),
                  _buildQuietHoursSection(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildNotificationTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notification Types',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...NotificationType.values
            .map((type) => _buildNotificationTypeSwitch(type)),
      ],
    );
  }

  Widget _buildNotificationTypeSwitch(NotificationType type) {
    final isEnabled = _preferences!.isTypeEnabled(type);
    final title = _getNotificationTypeTitle(type);
    final subtitle = _getNotificationTypeSubtitle(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: isEnabled,
        onChanged: (value) {
          setState(() {
            if (value) {
              _preferences!.enableType(type);
            } else {
              _preferences!.disableType(type);
            }
          });
        },
      ),
    );
  }

  Widget _buildTimingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferred Times',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildTimePicker('Morning', 'morning'),
        const SizedBox(height: 8),
        _buildTimePicker('Afternoon', 'afternoon'),
        const SizedBox(height: 8),
        _buildTimePicker('Evening', 'evening'),
      ],
    );
  }

  Widget _buildTimePicker(String label, String key) {
    final timeString = _preferences!.preferredTimes[key] ?? '08:00';
    final time = TimeOfDay.fromDateTime(
      DateTime.parse('2023-01-01 $timeString:00'),
    );

    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(time.format(context)),
        trailing: const Icon(Icons.access_time),
        onTap: () async {
          final newTime = await showTimePicker(
            context: context,
            initialTime: time,
          );
          if (newTime != null) {
            setState(() {
              _preferences!.preferredTimes[key] =
                  '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
            });
          }
        },
      ),
    );
  }

  Widget _buildFrequencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notification Frequency',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: NotificationFrequency.values.map((frequency) {
              return RadioListTile<NotificationFrequency>(
                title: Text(_getFrequencyTitle(frequency)),
                subtitle: Text(_getFrequencySubtitle(frequency)),
                value: frequency,
                groupValue: _preferences!.frequency,
                onChanged: (value) {
                  setState(() {
                    _preferences = _preferences!.copyWith(frequency: value);
                  });
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            title: const Text('Maximum Daily Notifications'),
            subtitle: Text(
                '${_preferences!.maxDailyNotifications} notifications per day'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _preferences!.maxDailyNotifications > 1
                      ? () {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              maxDailyNotifications:
                                  _preferences!.maxDailyNotifications - 1,
                            );
                          });
                        }
                      : null,
                ),
                Text('${_preferences!.maxDailyNotifications}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _preferences!.maxDailyNotifications < 10
                      ? () {
                          setState(() {
                            _preferences = _preferences!.copyWith(
                              maxDailyNotifications:
                                  _preferences!.maxDailyNotifications + 1,
                            );
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuietHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quiet Hours',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _buildTimePicker('Start Time', 'start'),
              const Divider(),
              _buildTimePicker('End Time', 'end'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updatePreferences,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Save Preferences',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  String _getNotificationTypeTitle(NotificationType type) {
    switch (type) {
      case NotificationType.healthGoal:
        return 'Health Goals';
      case NotificationType.pantryExpiry:
        return 'Pantry Alerts';
      case NotificationType.education:
        return 'Educational Content';
      case NotificationType.system:
        return 'System Notifications';
    }
  }

  String _getNotificationTypeSubtitle(NotificationType type) {
    switch (type) {
      case NotificationType.healthGoal:
        return 'Daily progress reminders and goal achievements';
      case NotificationType.pantryExpiry:
        return 'Expiration alerts and recipe suggestions';
      case NotificationType.education:
        return 'Health tips and educational articles';
      case NotificationType.system:
        return 'App updates and general notifications';
    }
  }

  String _getFrequencyTitle(NotificationFrequency frequency) {
    switch (frequency) {
      case NotificationFrequency.low:
        return 'Low';
      case NotificationFrequency.medium:
        return 'Medium';
      case NotificationFrequency.high:
        return 'High';
    }
  }

  String _getFrequencySubtitle(NotificationFrequency frequency) {
    switch (frequency) {
      case NotificationFrequency.low:
        return '1-2 notifications per day';
      case NotificationFrequency.medium:
        return '2-3 notifications per day';
      case NotificationFrequency.high:
        return '3-5 notifications per day';
    }
  }
}

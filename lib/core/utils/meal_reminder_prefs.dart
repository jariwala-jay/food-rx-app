import 'package:flutter/material.dart';

/// Shared helpers for reading/writing the `mealLoggingReminderPrefs` map
/// stored on `UserModel`, used by both the Notification Preferences page and
/// `NotificationService`. Both readers must apply identical logic — see
/// [isMealReminderEnabled] — or the settings UI and the actual scheduled
/// notifications can disagree.
///
/// Shape (current and only format going forward):
/// `{enabled: bool, breakfast: {enabled, hour, minute}, lunch: {...}, dinner: {...}}`
///
/// `enabled` is the master "Meal reminders" switch: when false, no meal
/// fires regardless of its own per-meal `enabled` value, and the per-meal
/// values are preserved untouched so turning the master back on restores
/// exactly what was set before. Old saved docs that predate per-meal
/// `enabled` keys (`{enabled: bool, breakfast: {hour, minute}, ...}`) are
/// still read correctly: a meal with no `enabled` key of its own inherits
/// the top-level flag, which — since no per-meal state ever existed for
/// those docs — plays the role of both "master" and "this meal" at once.
const List<String> mealReminderOrder = ['breakfast', 'lunch', 'dinner'];

/// Whether the master "Meal reminders" switch is on. When this is false,
/// every meal is disabled regardless of its own per-meal flag.
bool isMealRemindersMasterEnabled(Map<String, dynamic>? prefs) {
  return prefs?['enabled'] == true;
}

/// [meal]'s own stored toggle position, ignoring the master switch
/// entirely. This is what the settings UI must load into its per-meal
/// state, so that switching the master off and back on redisplays each
/// meal exactly as it was left — never forced on or off by the master
/// having been toggled. A meal with no `enabled` key of its own (an
/// old-format doc, saved before per-meal flags existed) inherits the
/// single top-level flag as its own state too.
bool mealReminderOwnEnabled(Map<String, dynamic>? prefs, String meal) {
  final mealPrefs = prefs?[meal];
  if (mealPrefs is Map && mealPrefs.containsKey('enabled')) {
    return mealPrefs['enabled'] == true;
  }
  return prefs?['enabled'] == true;
}

/// Whether [meal]'s reminder should actually fire: the master switch must
/// be on AND that meal's own toggle ([mealReminderOwnEnabled]) must be on.
/// This is the function scheduling decisions must use — never
/// [mealReminderOwnEnabled] alone, which ignores the master.
bool isMealReminderEnabled(Map<String, dynamic>? prefs, String meal) {
  return isMealRemindersMasterEnabled(prefs) &&
      mealReminderOwnEnabled(prefs, meal);
}

/// The time of day for [meal] in [prefs], or [fallback] if that meal's
/// entry is missing or malformed (not a Map, or missing/non-int
/// hour/minute). Independent of enabled state on purpose — a disabled
/// meal's chosen time must survive being toggled off and back on.
TimeOfDay mealReminderTimeOfDay(
  Map<String, dynamic>? prefs,
  String meal,
  TimeOfDay fallback,
) {
  final mealPrefs = prefs?[meal];
  if (mealPrefs is Map && mealPrefs['hour'] is int && mealPrefs['minute'] is int) {
    return TimeOfDay(
      hour: mealPrefs['hour'] as int,
      minute: mealPrefs['minute'] as int,
    );
  }
  return fallback;
}

/// Builds the payload to persist: a top-level `enabled` for the master
/// switch, plus each meal's own `enabled`, `hour`, and `minute`.
Map<String, dynamic> buildMealReminderPrefsPayload({
  required bool masterEnabled,
  required Map<String, bool> enabled,
  required Map<String, TimeOfDay> times,
}) {
  return {
    'enabled': masterEnabled,
    for (final meal in mealReminderOrder)
      meal: {
        'enabled': enabled[meal] ?? false,
        'hour': times[meal]!.hour,
        'minute': times[meal]!.minute,
      },
  };
}

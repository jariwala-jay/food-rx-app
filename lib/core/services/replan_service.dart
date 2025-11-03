import 'package:flutter_app/core/services/personalization_service.dart';
import 'package:flutter_app/core/models/user_model.dart';

class ReplanTrigger {
  final String
      type; // 'weight_change', 'activity_change', 'condition_change', 'age_change', 'height_change', 'dob_change'
  final String description;
  final DateTime triggeredAt;
  final Map<String, dynamic> oldValue;
  final Map<String, dynamic> newValue;

  ReplanTrigger({
    required this.type,
    required this.description,
    required this.triggeredAt,
    required this.oldValue,
    required this.newValue,
  });
}

class ReplanService {
  final PersonalizationService _personalizationService;

  ReplanService(this._personalizationService);

  /// Check if a re-plan is needed based on user changes
  Future<ReplanTrigger?> checkReplanTriggers(
      UserModel oldUser, UserModel newUser) async {
    // Check DOB change (any change triggers recalculation since it affects age and BMR)
    if (oldUser.dateOfBirth != null && newUser.dateOfBirth != null) {
      if (oldUser.dateOfBirth != newUser.dateOfBirth) {
        final oldAge =
            DateTime.now().difference(oldUser.dateOfBirth!).inDays ~/ 365;
        final newAge =
            DateTime.now().difference(newUser.dateOfBirth!).inDays ~/ 365;
        return ReplanTrigger(
          type: 'dob_change',
          description: 'Date of birth changed (age: $oldAge → $newAge)',
          triggeredAt: DateTime.now(),
          oldValue: {
            'dateOfBirth': oldUser.dateOfBirth?.toIso8601String(),
            'age': oldAge
          },
          newValue: {
            'dateOfBirth': newUser.dateOfBirth?.toIso8601String(),
            'age': newAge
          },
        );
      }
    }

    // Check height change (any change triggers recalculation since it affects BMR)
    if ((oldUser.heightFeet != newUser.heightFeet) ||
        (oldUser.heightInches != newUser.heightInches)) {
      final oldHeightInches =
          (oldUser.heightFeet ?? 0) * 12 + (oldUser.heightInches ?? 0);
      final newHeightInches =
          (newUser.heightFeet ?? 0) * 12 + (newUser.heightInches ?? 0);
      return ReplanTrigger(
        type: 'height_change',
        description:
            'Height changed from ${oldHeightInches.toStringAsFixed(0)}" to ${newHeightInches.toStringAsFixed(0)}"',
        triggeredAt: DateTime.now(),
        oldValue: {
          'heightFeet': oldUser.heightFeet,
          'heightInches': oldUser.heightInches,
        },
        newValue: {
          'heightFeet': newUser.heightFeet,
          'heightInches': newUser.heightInches,
        },
      );
    }

    // Check weight change (any change triggers recalculation since it affects BMR)
    if (oldUser.weight != null && newUser.weight != null) {
      if ((oldUser.weight! - newUser.weight!).abs() > 0.1) {
        // Any weight change greater than 0.1 lbs triggers recalculation
        final weightChangePercent =
            ((newUser.weight! - oldUser.weight!) / oldUser.weight!) * 100;
        return ReplanTrigger(
          type: 'weight_change',
          description:
              'Weight changed by ${weightChangePercent.toStringAsFixed(1)}%',
          triggeredAt: DateTime.now(),
          oldValue: {'weight': oldUser.weight},
          newValue: {'weight': newUser.weight},
        );
      }
    }

    // Check activity level change
    if (oldUser.activityLevel != newUser.activityLevel) {
      return ReplanTrigger(
        type: 'activity_change',
        description:
            'Activity level changed from ${oldUser.activityLevel} to ${newUser.activityLevel}',
        triggeredAt: DateTime.now(),
        oldValue: {'activityLevel': oldUser.activityLevel},
        newValue: {'activityLevel': newUser.activityLevel},
      );
    }

    // Check medical conditions change
    final oldConditions = oldUser.medicalConditions ?? [];
    final newConditions = newUser.medicalConditions ?? [];
    if (!_listsEqual(oldConditions, newConditions)) {
      return ReplanTrigger(
        type: 'condition_change',
        description: 'Medical conditions changed',
        triggeredAt: DateTime.now(),
        oldValue: {'medicalConditions': oldConditions},
        newValue: {'medicalConditions': newConditions},
      );
    }

    // Check health goals change
    final oldGoals = oldUser.healthGoals;
    final newGoals = newUser.healthGoals;
    if (!_listsEqual(oldGoals, newGoals)) {
      return ReplanTrigger(
        type: 'condition_change',
        description: 'Health goals changed',
        triggeredAt: DateTime.now(),
        oldValue: {'healthGoals': oldGoals},
        newValue: {'healthGoals': newGoals},
      );
    }

    return null; // No re-plan needed
  }

  /// Generate a new personalized diet plan
  Future<PersonalizationResult> generateNewPlan(UserModel user) async {
    if (user.dateOfBirth == null ||
        user.gender == null ||
        user.heightFeet == null ||
        user.heightInches == null ||
        user.weight == null ||
        user.activityLevel == null) {
      throw Exception('Insufficient user data for personalization');
    }

    return _personalizationService.personalize(
      dob: user.dateOfBirth!,
      sex: user.gender!,
      heightFeet: user.heightFeet!,
      heightInches: user.heightInches!,
      weightLb: user.weight!,
      activityLevel: user.activityLevel!,
      medicalConditions: user.medicalConditions ?? [],
      healthGoals: user.healthGoals,
    );
  }

  /// Check if user should be offered re-planning
  bool shouldOfferReplan(UserModel user) {
    // Offer re-plan if user hasn't updated their plan in 6 months
    if (user.updatedAt != null) {
      final monthsSinceUpdate =
          DateTime.now().difference(user.updatedAt!).inDays / 30;
      return monthsSinceUpdate >= 6;
    }

    // Offer re-plan if user has no personalized plan data
    return user.selectedDietPlan == null || user.targetCalories == null;
  }

  /// Get re-plan suggestions based on user's current state
  List<String> getReplanSuggestions(UserModel user) {
    final suggestions = <String>[];

    if (user.selectedDietPlan == null) {
      suggestions.add('Set up your personalized diet plan');
    }

    if (user.targetCalories == null) {
      suggestions.add('Calculate your daily calorie targets');
    }

    if (user.weight == null ||
        user.heightFeet == null ||
        user.heightInches == null) {
      suggestions
          .add('Update your height and weight for accurate calculations');
    }

    if (user.activityLevel == null) {
      suggestions.add('Set your activity level for better recommendations');
    }

    if (user.medicalConditions?.isEmpty ?? true) {
      suggestions.add('Add any medical conditions for personalized guidance');
    }

    return suggestions;
  }

  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    final set1 = list1.toSet();
    final set2 = list2.toSet();
    return set1.difference(set2).isEmpty && set2.difference(set1).isEmpty;
  }
}

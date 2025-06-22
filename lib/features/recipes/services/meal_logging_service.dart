import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/tracking/services/tracker_service.dart';
import 'package:flutter_app/features/tracking/controller/tracker_provider.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/features/tracking/services/diet_plan_service.dart';
import 'dart:developer' as developer;

class MealLoggingService {
  final TrackerService _trackerService;
  final TrackerProvider _trackerProvider;
  final DietPlanService _dietPlanService;

  MealLoggingService({
    required TrackerService trackerService,
    required TrackerProvider trackerProvider,
    required DietPlanService dietPlanService,
  })  : _trackerService = trackerService,
        _trackerProvider = trackerProvider,
        _dietPlanService = dietPlanService;

  /// Log a meal consumption and update diet trackers
  Future<MealLoggingResult> logMealConsumption({
    required Recipe recipe,
    required int servingsConsumed,
    required String userId,
    required String dietType,
  }) async {
    try {
      developer.log(
        'Starting meal logging for recipe: ${recipe.title}, servings: $servingsConsumed',
        name: 'MealLoggingService',
      );

      final dietPlan = _dietPlanService.getDietPlan(dietType);
      final allTrackers = await _trackerService.getTrackers(userId, dietType);

      if (allTrackers.isEmpty) {
        throw Exception(
            'No trackers found for user. Please initialize trackers first.');
      }

      final trackerUpdates = <TrackerUpdate>[];

      // Process each ingredient in the recipe
      for (final ingredient in recipe.extendedIngredients) {
        final servingsMap = dietPlan.getServingsForIngredient(
          ingredientName: ingredient.nameClean ?? ingredient.name,
          amount: ingredient.amount * servingsConsumed,
          unit: ingredient.unit,
        );

        for (final entry in servingsMap.entries) {
          final category = entry.key;
          final servingEquivalents = entry.value;

          final tracker =
              allTrackers.where((t) => t.category == category).firstOrNull;

          if (tracker != null && servingEquivalents > 0) {
            trackerUpdates.add(TrackerUpdate(
              trackerId: tracker.id,
              trackerName: tracker.name,
              category: category,
              servingEquivalents: servingEquivalents,
              ingredientName: ingredient.nameClean ?? ingredient.name,
              ingredientAmount: ingredient.amount * servingsConsumed,
              ingredientUnit: ingredient.unit,
            ));
            developer.log(
              'Will update tracker "${tracker.name}" with $servingEquivalents servings from ${ingredient.name}',
              name: 'MealLoggingService',
            );
          }
        }
      }

      // Handle sodium tracking from nutrition data (for DASH diet)
      if (dietType.toLowerCase() == 'dash' && recipe.nutrition != null) {
        final sodiumTracker = allTrackers
            .where((t) => t.category == TrackerCategory.sodium)
            .firstOrNull;
        if (sodiumTracker != null) {
          final sodiumNutrient = recipe.nutrition!.nutrients
              .where((n) => n.name.toLowerCase() == 'sodium')
              .firstOrNull;

          if (sodiumNutrient != null) {
            final sodiumAmount = sodiumNutrient.amount * servingsConsumed;
            trackerUpdates.add(TrackerUpdate(
              trackerId: sodiumTracker.id,
              trackerName: sodiumTracker.name,
              category: TrackerCategory.sodium,
              servingEquivalents: sodiumAmount, // Direct mg amount for sodium
              ingredientName: 'Recipe nutrition',
              ingredientAmount: sodiumAmount,
              ingredientUnit: 'mg',
            ));
            developer.log(
              'Will update sodium tracker with ${sodiumAmount}mg from recipe nutrition',
              name: 'MealLoggingService',
            );
          }
        }
      }

      // Apply all tracker updates
      final updateResults = <String, bool>{};
      for (final update in trackerUpdates) {
        try {
          // Get current tracker value
          final currentTracker =
              allTrackers.where((t) => t.id == update.trackerId).first;
          final newValue =
              currentTracker.currentValue + update.servingEquivalents;

          // Update the tracker using TrackerService
          await _trackerService.updateTrackerValue(update.trackerId, newValue);

          // Also update through TrackerProvider for immediate UI refresh
          await _trackerProvider.updateTrackerValue(update.trackerId, newValue);

          updateResults[update.trackerName] = true;

          developer.log(
            'Successfully updated ${update.trackerName}: ${currentTracker.currentValue} -> $newValue',
            name: 'MealLoggingService',
          );
        } catch (e) {
          developer.log(
            'Failed to update tracker ${update.trackerName}: $e',
            name: 'MealLoggingService',
          );
          updateResults[update.trackerName] = false;
        }
      }

      // Force a UI notification to ensure widgets rebuild
      _trackerProvider.forceUIRefresh();

      return MealLoggingResult(
        success: true,
        trackerUpdates: trackerUpdates,
        updateResults: updateResults,
        totalServingsLogged: servingsConsumed,
      );
    } catch (e) {
      developer.log('Error in meal logging: $e', name: 'MealLoggingService');
      return MealLoggingResult(
        success: false,
        error: e.toString(),
        trackerUpdates: [],
        updateResults: {},
        totalServingsLogged: 0,
      );
    }
  }

  /// Get a summary of what would be tracked for a recipe (preview)
  Future<List<TrackerPreview>> getTrackingPreview({
    required Recipe recipe,
    required int servingsConsumed,
    required String userId,
    required String dietType,
  }) async {
    try {
      final dietPlan = _dietPlanService.getDietPlan(dietType);
      final allTrackers = await _trackerService.getTrackers(userId, dietType);
      final previews = <TrackerPreview>[];

      // Process each ingredient
      for (final ingredient in recipe.extendedIngredients) {
        final servingsMap = dietPlan.getServingsForIngredient(
          ingredientName: ingredient.nameClean ?? ingredient.name,
          amount: ingredient.amount * servingsConsumed,
          unit: ingredient.unit,
        );

        for (final entry in servingsMap.entries) {
          final category = entry.key;
          final servingEquivalents = entry.value;
          final tracker =
              allTrackers.where((t) => t.category == category).firstOrNull;

          if (tracker != null && servingEquivalents > 0) {
            // Check if we already have a preview for this tracker
            final existingPreview =
                previews.where((p) => p.trackerId == tracker.id).firstOrNull;
            if (existingPreview != null) {
              existingPreview.addServings(servingEquivalents);
            } else {
              previews.add(TrackerPreview(
                trackerId: tracker.id,
                trackerName: tracker.name,
                category: category,
                currentValue: tracker.currentValue,
                goalValue: tracker.goalValue,
                servingsToAdd: servingEquivalents,
                unit: tracker.unitString,
              ));
            }
          }
        }
      }

      // Handle sodium for DASH diet
      if (dietType.toLowerCase() == 'dash' && recipe.nutrition != null) {
        final sodiumTracker = allTrackers
            .where((t) => t.category == TrackerCategory.sodium)
            .firstOrNull;
        if (sodiumTracker != null) {
          final sodiumNutrient = recipe.nutrition!.nutrients
              .where((n) => n.name.toLowerCase() == 'sodium')
              .firstOrNull;

          if (sodiumNutrient != null) {
            final sodiumAmount = sodiumNutrient.amount * servingsConsumed;
            previews.add(TrackerPreview(
              trackerId: sodiumTracker.id,
              trackerName: sodiumTracker.name,
              category: TrackerCategory.sodium,
              currentValue: sodiumTracker.currentValue,
              goalValue: sodiumTracker.goalValue,
              servingsToAdd: sodiumAmount,
              unit: sodiumTracker.unitString,
            ));
          }
        }
      }

      return previews;
    } catch (e) {
      developer.log('Error generating tracking preview: $e',
          name: 'MealLoggingService');
      return [];
    }
  }
}

/// Result of a meal logging operation
class MealLoggingResult {
  final bool success;
  final String? error;
  final List<TrackerUpdate> trackerUpdates;
  final Map<String, bool> updateResults; // tracker name -> success
  final int totalServingsLogged;

  MealLoggingResult({
    required this.success,
    this.error,
    required this.trackerUpdates,
    required this.updateResults,
    required this.totalServingsLogged,
  });

  List<String> get successfulUpdates =>
      updateResults.entries.where((e) => e.value).map((e) => e.key).toList();

  List<String> get failedUpdates =>
      updateResults.entries.where((e) => !e.value).map((e) => e.key).toList();
}

/// Represents an update to be made to a tracker
class TrackerUpdate {
  final String trackerId;
  final String trackerName;
  final TrackerCategory category;
  final double servingEquivalents;
  final String ingredientName;
  final double ingredientAmount;
  final String ingredientUnit;

  TrackerUpdate({
    required this.trackerId,
    required this.trackerName,
    required this.category,
    required this.servingEquivalents,
    required this.ingredientName,
    required this.ingredientAmount,
    required this.ingredientUnit,
  });
}

/// Preview of what would be tracked for a recipe
class TrackerPreview {
  final String trackerId;
  final String trackerName;
  final TrackerCategory category;
  final double currentValue;
  final double goalValue;
  double servingsToAdd;
  final String unit;

  TrackerPreview({
    required this.trackerId,
    required this.trackerName,
    required this.category,
    required this.currentValue,
    required this.goalValue,
    required this.servingsToAdd,
    required this.unit,
  });

  void addServings(double additionalServings) {
    servingsToAdd += additionalServings;
  }

  double get newValue => currentValue + servingsToAdd;
  double get newProgress => goalValue > 0 ? (newValue / goalValue) : 0.0;

  String get formattedCurrent => _formatValue(currentValue);
  String get formattedNew => _formatValue(newValue);
  String get formattedGoal => _formatValue(goalValue);
  String get formattedToAdd => _formatValue(servingsToAdd);

  String _formatValue(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    } else {
      return value.toStringAsFixed(1);
    }
  }
}

/// Extension to help find first or null
extension FirstWhereOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }

  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

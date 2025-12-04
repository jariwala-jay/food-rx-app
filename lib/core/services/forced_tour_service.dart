import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';

class ForcedTourService {
  final AuthController _authController;

  ForcedTourService({
    required AuthController authController,
  }) : _authController = authController;

  /// Check if the current user should see the tour
  bool shouldShowTour() {
    final user = _authController.currentUser;

    final shouldShow = user != null && !user.hasCompletedTour;
    return shouldShow;
  }

  /// Mark the entire tour as completed
  Future<bool> completeTour() async {
    try {
      final user = _authController.currentUser;
      if (user == null) return false;

      // Update in database
      await _authController.updateUserProfile({'hasCompletedTour': true});
      return true;
    } catch (e) {
      print('Error completing tour: $e');
      return false;
    }
  }

  /// Reset tour for testing purposes
  Future<bool> resetTour() async {
    try {
      final user = _authController.currentUser;
      if (user == null) return false;

      // Update in database
      await _authController.updateUserProfile({'hasCompletedTour': false});
      return true;
    } catch (e) {
      print('Error resetting tour: $e');
      return false;
    }
  }

  /// Get the next tour step
  TourStep? getNextStep(TourStep currentStep) {
    switch (currentStep) {
      case TourStep.trackers:
        return TourStep.trackerInfo;
      case TourStep.trackerInfo:
        return TourStep.dailyTips;
      case TourStep.dailyTips:
        return TourStep.myPlan;
      case TourStep.myPlan:
        return TourStep.addButton;
      case TourStep.addButton:
        return TourStep.selectCategory;
      case TourStep.selectCategory:
        return TourStep.setQuantityUnit;
      case TourStep.setQuantityUnit:
        return TourStep.saveItem;
      case TourStep.saveItem:
        return TourStep.pantryItems;
      case TourStep.pantryItems:
        return TourStep.removePantryItem;
      case TourStep.removePantryItem:
        return TourStep.recipes;
      case TourStep.recipes:
        return TourStep.education;
      case TourStep.education:
        return null; // Tour is complete
      case TourStep.selectItem:
        // This step is no longer used, but kept for enum completeness
        return TourStep.setQuantityUnit;
    }
  }

  /// Check if this is the last step of the tour
  bool isLastStep(TourStep step) {
    return step == TourStep.education;
  }

  /// Get tour step description
  String getStepDescription(TourStep step) {
    switch (step) {
      case TourStep.trackers:
        return TourDescriptions.trackers;
      case TourStep.trackerInfo:
        return TourDescriptions.trackerInfo;
      case TourStep.dailyTips:
        return TourDescriptions.dailyTips;
      case TourStep.myPlan:
        return TourDescriptions.myPlan;
      case TourStep.addButton:
        return TourDescriptions.addButton;
      case TourStep.selectCategory:
        return TourDescriptions.selectCategory;
      case TourStep.setQuantityUnit:
        return TourDescriptions.setQuantityUnit;
      case TourStep.saveItem:
        return TourDescriptions.saveItem;
      case TourStep.pantryItems:
        return TourDescriptions.pantryItems;
      case TourStep.removePantryItem:
        return TourDescriptions.removePantryItem;
      case TourStep.recipes:
        return TourDescriptions.recipes;
      case TourStep.education:
        return TourDescriptions.education;
      case TourStep.selectItem:
        // This step is no longer used
        return TourDescriptions.selectItem;
    }
  }

  /// Get tour step title
  String getStepTitle(TourStep step) {
    switch (step) {
      case TourStep.trackers:
        return 'Track Your Nutrition';
      case TourStep.trackerInfo:
        return 'Serving Size Info';
      case TourStep.dailyTips:
        return 'Daily Health Tips';
      case TourStep.myPlan:
        return 'Your Meal Plan';
      case TourStep.addButton:
        return 'Add Items';
      case TourStep.selectCategory:
        return 'Select Category';
      case TourStep.setQuantityUnit:
        return 'Set Quantity & Unit';
      case TourStep.saveItem:
        return 'Save Item';
      case TourStep.pantryItems:
        return 'Your Pantry';
      case TourStep.removePantryItem:
        return 'Remove Items';
      case TourStep.recipes:
        return 'Personalized Recipes';
      case TourStep.education:
        return 'Health Education';
      case TourStep.selectItem:
        // This step is no longer used
        return 'Select Item';
    }
  }
}

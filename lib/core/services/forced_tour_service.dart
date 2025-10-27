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
        return TourStep.dailyTips;
      case TourStep.dailyTips:
        return TourStep.myPlan;
      case TourStep.myPlan:
        return TourStep.addButton;
      case TourStep.addButton:
        return TourStep.pantryItems;
      case TourStep.pantryItems:
        return TourStep.recipes;
      case TourStep.recipes:
        return TourStep.education;
      case TourStep.education:
        return null; // Tour is complete
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
      case TourStep.dailyTips:
        return TourDescriptions.dailyTips;
      case TourStep.myPlan:
        return TourDescriptions.myPlan;
      case TourStep.addButton:
        return TourDescriptions.addButton;
      case TourStep.pantryItems:
        return TourDescriptions.pantryItems;
      case TourStep.recipes:
        return TourDescriptions.recipes;
      case TourStep.education:
        return TourDescriptions.education;
    }
  }

  /// Get tour step title
  String getStepTitle(TourStep step) {
    switch (step) {
      case TourStep.trackers:
        return 'Track Your Nutrition';
      case TourStep.dailyTips:
        return 'Daily Health Tips';
      case TourStep.myPlan:
        return 'Your Diet Plan';
      case TourStep.addButton:
        return 'Add Items';
      case TourStep.pantryItems:
        return 'Your Pantry';
      case TourStep.recipes:
        return 'Personalized Recipes';
      case TourStep.education:
        return 'Health Education';
    }
  }
}

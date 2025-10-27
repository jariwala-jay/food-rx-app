import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';

class TourService {
  final AuthController _authController;

  TourService({
    required AuthController authController,
  }) : _authController = authController;

  /// Check if the current user should see the tour
  bool shouldShowTour() {
    final user = _authController.currentUser;

    final shouldShow = user != null && !user.hasCompletedTour;
    return shouldShow;
  }

  /// Complete a specific tour step
  Future<void> completeTourStep(TourStep step) async {
    // This could be used to track progress if needed
    // For now, we'll just log it
    print('Tour step completed: $step');
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
}

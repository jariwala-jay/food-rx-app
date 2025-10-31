import 'package:flutter/material.dart';
import 'package:flutter_app/core/services/tour_service.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';

class TourProvider extends ChangeNotifier {
  TourService _tourService;

  TourProvider({required TourService tourService}) : _tourService = tourService;

  bool _isTourActive = false;
  TourStep _currentStep = TourStep.trackers;
  bool _tourCompleted = false;

  // Getters
  bool get isTourActive => _isTourActive;
  TourStep get currentStep => _currentStep;
  bool get tourCompleted => _tourCompleted;

  /// Start the tour for first-time users
  void startTour() {
    print(
        '🎯 TourProvider: shouldShowTour() = ${_tourService.shouldShowTour()}');

    if (_tourService.shouldShowTour()) {
      _isTourActive = true;
      _currentStep = TourStep.trackers;
      _tourCompleted = false;
      notifyListeners();

      // Force start the showcase after a short delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        notifyListeners(); // Trigger rebuild to show showcase
      });
    } else {
      print(
          '🎯 TourProvider: Tour not needed - user has already completed it or not logged in');
    }
  }

  /// Complete the current tour step and move to the next
  void completeCurrentStep() {
    if (!_isTourActive) return;

    _tourService.completeTourStep(_currentStep);

    final nextStep = _tourService.getNextStep(_currentStep);
    if (nextStep != null) {
      _currentStep = nextStep;
      notifyListeners();

      // Trigger the next showcase after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        notifyListeners(); // This will cause MainScreen to rebuild and trigger showcase
      });
    } else {
      // Tour is complete
      _isTourActive = false;
      _tourCompleted = true;
      notifyListeners();
    }
  }

  /// Get the current step's showcase key
  GlobalKey? getCurrentStepKey() {
    switch (_currentStep) {
      case TourStep.trackers:
        return TourKeys.trackerSectionKey;
      case TourStep.trackerInfo:
        return TourKeys.trackerInfoKey;
      case TourStep.dailyTips:
        return TourKeys.dailyTipsKey;
      case TourStep.myPlan:
        return TourKeys.myPlanButtonKey;
      case TourStep.addButton:
        return TourKeys.addButtonKey;
      case TourStep.pantryItems:
        return TourKeys.pantryItemsKey;
      case TourStep.recipes:
        return TourKeys.recipeListKey;
      case TourStep.education:
        return TourKeys.educationContentKey;
    }
  }

  /// Skip to a specific step (useful for navigation)
  void skipToStep(TourStep step) {
    if (!_isTourActive) return;

    _currentStep = step;
    notifyListeners();
  }

  /// Complete the entire tour
  Future<void> completeTour() async {
    if (!_isTourActive) return;

    final success = await _tourService.completeTour();
    if (success) {
      _isTourActive = false;
      _tourCompleted = true;
      notifyListeners();
    }
  }

  /// End the tour without marking as completed
  void endTour() {
    _isTourActive = false;
    notifyListeners();
  }

  /// Skip the tour entirely
  Future<void> skipTour() async {
    await completeTour();
  }

  /// Reset tour for testing
  Future<void> resetTour() async {
    final success = await _tourService.resetTour();
    if (success) {
      _tourCompleted = false;
      notifyListeners();
    }
  }

  /// Check if we're currently on a specific step
  bool isOnStep(TourStep step) {
    return _isTourActive && _currentStep == step;
  }

  /// Force user to interact with a specific element
  void forceInteraction(TourStep step) {
    if (!_isTourActive || _currentStep != step) return;

    // This will be handled by the UI to show specific instructions
    notifyListeners();
  }

  /// Check if user must interact with specific element
  bool requiresSpecificInteraction(TourStep step) {
    return _isTourActive && _currentStep == step;
  }
}

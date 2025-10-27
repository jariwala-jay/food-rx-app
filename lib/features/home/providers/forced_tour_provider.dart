import 'package:flutter/material.dart';
import 'package:flutter_app/core/services/forced_tour_service.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';

class ForcedTourProvider extends ChangeNotifier {
  final ForcedTourService _tourService;

  ForcedTourProvider({required ForcedTourService tourService})
      : _tourService = tourService;

  // Expose tour service for external access
  ForcedTourService get tourService => _tourService;

  bool _isTourActive = false;
  TourStep _currentStep = TourStep.trackers;
  bool _tourCompleted = false;

  // Getters
  bool get isTourActive => _isTourActive;
  TourStep get currentStep => _currentStep;
  bool get tourCompleted => _tourCompleted;

  /// Start the tour for first-time users
  void startTour() {
    if (_tourService.shouldShowTour()) {
      _isTourActive = true;
      _currentStep = TourStep.trackers;
      _tourCompleted = false;
      notifyListeners();
    }
  }

  /// Mark the current step as completed
  void completeCurrentStep() {
    if (!_isTourActive) return;

    // Move to next step immediately
    final nextStep = _tourService.getNextStep(_currentStep);
    if (nextStep != null) {
      _currentStep = nextStep;
    } else {
      completeTourSync();
    }

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

  /// Complete the entire tour synchronously (for testing)
  void completeTourSync() {
    if (!_isTourActive) return;

    _isTourActive = false;
    _tourCompleted = true;
    notifyListeners();
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
      _isTourActive = false;
      _tourCompleted = false;
      _currentStep = TourStep.trackers;
      notifyListeners();
    }
  }

  /// Check if we're currently on a specific step
  bool isOnStep(TourStep step) {
    return _isTourActive && _currentStep == step;
  }

  /// Get current step description
  String getCurrentStepDescription() {
    return _tourService.getStepDescription(_currentStep);
  }

  /// Get current step title
  String getCurrentStepTitle() {
    return _tourService.getStepTitle(_currentStep);
  }

  /// Check if this is the last step
  bool isLastStep() {
    return _tourService.isLastStep(_currentStep);
  }

  /// Force user to interact with current step
  void forceInteraction() {
    if (!_isTourActive) return;

    notifyListeners();
  }
}

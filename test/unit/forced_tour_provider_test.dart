import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:flutter_app/core/services/forced_tour_service.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/models/user_model.dart';

// Mock AuthController for testing
class MockAuthController extends AuthController {
  bool _hasCompletedTour = false;

  @override
  bool get hasCompletedTour => _hasCompletedTour;

  @override
  UserModel? get currentUser => UserModel(
        id: 'test-user-id',
        email: 'test@example.com',
        hasCompletedTour: _hasCompletedTour,
      );

  void setTourCompleted(bool completed) {
    _hasCompletedTour = completed;
  }
}

const _tourDisabled =
    'Tour feature disabled — re-enable when shouldShowTour() is uncommented in forced_tour_service.dart';

void main() {
  group('ForcedTourProvider', () {
    late MockAuthController mockAuthController;
    late ForcedTourService tourService;
    late ForcedTourProvider tourProvider;

    setUp(() {
      mockAuthController = MockAuthController();
      tourService = ForcedTourService(authController: mockAuthController);
      tourProvider = ForcedTourProvider(tourService: tourService);
    });

    test('should start tour for new user', skip: _tourDisabled, () {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      expect(tourProvider.isTourActive, true);
      expect(tourProvider.currentStep, TourStep.trackers);
      expect(tourProvider.tourCompleted, false);
    });

    test('should not start tour for user who completed it', () {
      mockAuthController.setTourCompleted(true);
      tourProvider.startTour();

      expect(tourProvider.isTourActive, false);
    });

    test('should progress through tour steps correctly', skip: _tourDisabled,
        () {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      expect(tourProvider.currentStep, TourStep.trackers);
      expect(tourProvider.isTourActive, true);

      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.dailyTips);

      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.myPlan);

      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.addButton);

      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.pantryItems);

      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.recipes);

      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.education);

      tourProvider.completeCurrentStep();
      expect(tourProvider.isTourActive, false);
      expect(tourProvider.tourCompleted, true);
    });

    test('should complete tour successfully', skip: _tourDisabled, () async {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      expect(tourProvider.isTourActive, true);

      await tourProvider.completeTour();

      expect(tourProvider.isTourActive, false);
      expect(tourProvider.tourCompleted, true);
    });

    test('should skip tour successfully', skip: _tourDisabled, () async {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      expect(tourProvider.isTourActive, true);

      await tourProvider.skipTour();

      expect(tourProvider.isTourActive, false);
      expect(tourProvider.tourCompleted, true);
    });

    test('should end tour without marking as completed', skip: _tourDisabled,
        () {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      expect(tourProvider.isTourActive, true);

      tourProvider.endTour();

      expect(tourProvider.isTourActive, false);
      expect(tourProvider.tourCompleted, false);
    });

    test('should reset tour for testing', () async {
      mockAuthController.setTourCompleted(true);

      await tourProvider.resetTour();

      expect(tourProvider.tourCompleted, false);
    });

    test('should check if on specific step', skip: _tourDisabled, () {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      expect(tourProvider.isOnStep(TourStep.trackers), true);
      expect(tourProvider.isOnStep(TourStep.dailyTips), false);

      tourProvider.completeCurrentStep();
      expect(tourProvider.isOnStep(TourStep.trackers), false);
      expect(tourProvider.isOnStep(TourStep.dailyTips), true);
    });

    test('should get current step description and title', () {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      expect(tourProvider.getCurrentStepDescription(), isNotEmpty);
      expect(tourProvider.getCurrentStepTitle(), isNotEmpty);
    });

    test('should check if last step', skip: _tourDisabled, () {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      expect(tourProvider.isLastStep(), false);

      tourProvider.completeCurrentStep();
      tourProvider.completeCurrentStep();
      tourProvider.completeCurrentStep();
      tourProvider.completeCurrentStep();
      tourProvider.completeCurrentStep();
      tourProvider.completeCurrentStep();

      expect(tourProvider.isLastStep(), true);
    });

    test('should force interaction with current step', skip: _tourDisabled, () {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      tourProvider.forceInteraction();

      expect(tourProvider.isTourActive, true);
    });
  });
}

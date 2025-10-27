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

    test('should start tour for new user', () {
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

    test('should progress through tour steps correctly', () {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      // Start at trackers
      expect(tourProvider.currentStep, TourStep.trackers);
      expect(tourProvider.isTourActive, true);

      // Complete trackers step
      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.dailyTips);

      // Complete daily tips step
      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.myPlan);

      // Complete my plan step
      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.addButton);

      // Complete add button step
      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.pantryItems);

      // Complete pantry items step
      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.recipes);

      // Complete recipes step
      tourProvider.completeCurrentStep();
      expect(tourProvider.currentStep, TourStep.education);

      // Complete education step (final step)
      tourProvider.completeCurrentStep();
      expect(tourProvider.isTourActive, false);
      expect(tourProvider.tourCompleted, true);
    });

    test('should complete tour successfully', () async {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      expect(tourProvider.isTourActive, true);

      await tourProvider.completeTour();

      expect(tourProvider.isTourActive, false);
      expect(tourProvider.tourCompleted, true);
    });

    test('should skip tour successfully', () async {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      expect(tourProvider.isTourActive, true);

      await tourProvider.skipTour();

      expect(tourProvider.isTourActive, false);
      expect(tourProvider.tourCompleted, true);
    });

    test('should end tour without marking as completed', () {
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

    test('should check if on specific step', () {
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

    test('should check if last step', () {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      // Start at first step
      expect(tourProvider.isLastStep(), false);

      // Progress to last step
      tourProvider.completeCurrentStep(); // trackers -> dailyTips
      tourProvider.completeCurrentStep(); // dailyTips -> myPlan
      tourProvider.completeCurrentStep(); // myPlan -> addButton
      tourProvider.completeCurrentStep(); // addButton -> pantryItems
      tourProvider.completeCurrentStep(); // pantryItems -> recipes
      tourProvider.completeCurrentStep(); // recipes -> education

      expect(tourProvider.isLastStep(), true);
    });

    test('should force interaction with current step', () {
      mockAuthController.setTourCompleted(false);
      tourProvider.startTour();

      tourProvider.forceInteraction();

      // Force interaction should trigger notifyListeners
      expect(tourProvider.isTourActive, true);
    });
  });
}

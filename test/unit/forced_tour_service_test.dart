import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/forced_tour_service.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:flutter_app/core/models/user_model.dart';

// Mock AuthController for testing
class MockAuthController extends AuthController {
  bool _hasCompletedTour = false;

  @override
  bool get isAuthenticated => true;

  @override
  UserModel? get currentUser => UserModel(
        id: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
        hasCompletedTour: _hasCompletedTour,
      );

  @override
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (updates.containsKey('hasCompletedTour')) {
      _hasCompletedTour = updates['hasCompletedTour'] as bool;
    }
  }

  void setTourCompleted(bool completed) {
    _hasCompletedTour = completed;
  }
}

void main() {
  group('ForcedTourService Tests', () {
    late MockAuthController mockAuthController;
    late ForcedTourService tourService;

    setUp(() {
      mockAuthController = MockAuthController();
      tourService = ForcedTourService(authController: mockAuthController);
    });

    test('should show tour for new user', () {
      mockAuthController.setTourCompleted(false);
      expect(tourService.shouldShowTour(), true);
    });

    test('should not show tour for user who completed it', () {
      mockAuthController.setTourCompleted(true);
      expect(tourService.shouldShowTour(), false);
    });

    test('should get correct next step', () {
      expect(tourService.getNextStep(TourStep.trackers), TourStep.dailyTips);
      expect(tourService.getNextStep(TourStep.dailyTips), TourStep.myPlan);
      expect(tourService.getNextStep(TourStep.myPlan), TourStep.addButton);
      expect(tourService.getNextStep(TourStep.addButton), TourStep.pantryItems);
      expect(tourService.getNextStep(TourStep.pantryItems), TourStep.recipes);
      expect(tourService.getNextStep(TourStep.recipes), TourStep.education);
      expect(tourService.getNextStep(TourStep.education), null);
    });

    test('should identify last step correctly', () {
      expect(tourService.isLastStep(TourStep.education), true);
      expect(tourService.isLastStep(TourStep.trackers), false);
    });

    test('should get correct step descriptions', () {
      expect(tourService.getStepDescription(TourStep.trackers), isNotEmpty);
      expect(tourService.getStepDescription(TourStep.dailyTips), isNotEmpty);
      expect(tourService.getStepDescription(TourStep.myPlan), isNotEmpty);
      expect(tourService.getStepDescription(TourStep.addButton), isNotEmpty);
      expect(tourService.getStepDescription(TourStep.pantryItems), isNotEmpty);
      expect(tourService.getStepDescription(TourStep.recipes), isNotEmpty);
      expect(tourService.getStepDescription(TourStep.education), isNotEmpty);
    });

    test('should get correct step titles', () {
      expect(
          tourService.getStepTitle(TourStep.trackers), 'Track Your Nutrition');
      expect(tourService.getStepTitle(TourStep.dailyTips), 'Daily Health Tips');
      expect(tourService.getStepTitle(TourStep.myPlan), 'Your Diet Plan');
      expect(tourService.getStepTitle(TourStep.addButton), 'Add Items');
      expect(tourService.getStepTitle(TourStep.pantryItems), 'Your Pantry');
      expect(
          tourService.getStepTitle(TourStep.recipes), 'Personalized Recipes');
      expect(tourService.getStepTitle(TourStep.education), 'Health Education');
    });
  });
}

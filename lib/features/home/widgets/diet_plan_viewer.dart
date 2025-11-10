import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/widgets/screenshot_viewer_widget.dart';
import 'package:flutter_app/features/home/widgets/plan_video_player.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';

class DietPlanViewer extends StatelessWidget {
  final String myPlanType;
  final bool showGlycemicIndex;

  const DietPlanViewer({
    Key? key,
    required this.myPlanType,
    this.showGlycemicIndex = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get display name based on plan type
    String displayName;
    switch (myPlanType) {
      case 'DiabetesPlate':
        displayName = 'Diabetes Plate (ADA)';
        break;
      case 'DASH':
        displayName = 'DASH Diet';
        break;
      case 'MyPlate':
        displayName = 'MyPlate Nutrition';
        break;
      case 'GlycemicIndex':
        displayName = 'Glycemic Index Guide';
        break;
      default:
        displayName = myPlanType;
    }

    // Check if tour is active and we're on the myPlan step
    return Consumer<ForcedTourProvider>(
      builder: (context, tourProvider, child) {
        final isTourActive = tourProvider.isTourActive;
        final isOnMyPlanStep = tourProvider.currentStep == TourStep.myPlan;

        // Show video during tour, slides otherwise
        if (isTourActive && isOnMyPlanStep) {
          return PlanVideoPlayer(
            planType: myPlanType,
            title: displayName,
            isTourActive: true,
          );
        } else {
          return ScreenshotViewerWidget(
            planType: myPlanType,
            title: displayName,
            showGlycemicIndex: showGlycemicIndex,
          );
        }
      },
    );
  }
}

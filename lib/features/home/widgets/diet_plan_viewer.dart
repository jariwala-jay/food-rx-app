import 'package:flutter/material.dart';
import 'package:flutter_app/features/home/widgets/screenshot_viewer_widget.dart';

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

    // Always show slides (same behavior for tour and non-tour)
    return ScreenshotViewerWidget(
      planType: myPlanType,
      title: displayName,
      showGlycemicIndex: showGlycemicIndex,
    );
  }
}

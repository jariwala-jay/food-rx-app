import 'package:flutter/material.dart';
import 'package:flutter_app/features/home/widgets/screenshot_viewer_widget.dart';

class DietPlanViewer extends StatelessWidget {
  final String myPlanType;

  const DietPlanViewer({
    Key? key,
    required this.myPlanType,
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

    return ScreenshotViewerWidget(
      planType: myPlanType,
      title: displayName,
    );
  }
}

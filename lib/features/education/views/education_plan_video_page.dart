import 'package:flutter/material.dart';
import 'package:flutter_app/features/home/widgets/plan_video_player.dart';

/// Full-screen video page for Education tab plan videos.
/// Shows the user's plan video (Diabetes Plate, DASH, or MyPlate) with a back button.
class EducationPlanVideoPage extends StatelessWidget {
  final String planType; // 'DiabetesPlate' | 'DASH' | 'MyPlate'
  final String title;

  const EducationPlanVideoPage({
    Key? key,
    required this.planType,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: PlanVideoPlayer(
            planType: planType,
            title: title,
            isTourActive: false,
            useFullVideo: true,
          ),
        ),
      ),
    );
  }
}

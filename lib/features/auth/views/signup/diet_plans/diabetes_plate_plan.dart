import 'package:flutter/material.dart';
import 'package:flutter_app/features/home/widgets/plan_video_player.dart';

class DiabetesPlatePlan extends StatelessWidget {
  final VoidCallback onFinish;

  const DiabetesPlatePlan({
    Key? key,
    required this.onFinish,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: PlanVideoPlayer(
          planType: 'DiabetesPlate',
          title: 'Diabetes Plate (ADA)',
          isTourActive: false,
          isSignupMode: true,
          onFinish: onFinish,
        ),
      ),
    );
  }
}

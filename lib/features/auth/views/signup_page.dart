import 'package:flutter/material.dart';
import 'package:flutter_app/features/auth/views/signup/basic_info_step.dart';
import 'package:flutter_app/features/auth/views/signup/health_info_step.dart';
import 'package:flutter_app/features/auth/views/signup/preferences_step.dart';
import 'package:flutter_app/features/auth/views/signup/other_details_step.dart';
import 'package:flutter_app/features/auth/views/signup/diet_plan_step.dart';
import 'package:flutter_app/features/auth/widgets/signup_progress_indicator.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  int _currentStep = 0;
  static const int _totalSteps = 5;

  void _handleNext() {
    setState(() {
      _currentStep++;
    });
  }

  void _handlePrevious() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  void _handleSubmit() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            SignupProgressIndicator(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
            ),
            // Step content
            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: [
                  BasicInfoStep(
                    onNext: _handleNext,
                  ),
                  HealthInfoStep(
                    onNext: _handleNext,
                    onPrevious: _handlePrevious,
                  ),
                  PreferencesStep(
                    onPrevious: _handlePrevious,
                    onSubmit: _handleNext,
                  ),
                  OtherDetailsStep(
                    onPrevious: _handlePrevious,
                    onSubmit: _handleNext,
                  ),
                  DietPlanStep(
                    onFinish: _handleSubmit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../signup/basic_info_step.dart';
import '../signup/health_info_step.dart';
import '../signup/preferences_step.dart';
import '../signup/diet_plan_step.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  int _currentStep = 0;

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
            DietPlanStep(
              onFinish: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

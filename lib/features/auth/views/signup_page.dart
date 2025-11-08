import 'package:flutter/material.dart';
import 'package:flutter_app/features/auth/views/signup/basic_info_step.dart';
import 'package:flutter_app/features/auth/views/signup/health_info_step.dart';
import 'package:flutter_app/features/auth/views/signup/preferences_step.dart';
import 'package:flutter_app/features/auth/views/signup/other_details_step.dart';
import 'package:flutter_app/features/auth/views/signup/diet_plan_step.dart';
import 'package:flutter_app/features/auth/widgets/signup_progress_indicator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/providers/signup_provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';

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

  Future<void> _handleSubmit() async {
    // Perform final registration here using collected data
    try {
      final signupProvider = context.read<SignupProvider>();
      final authController = context.read<AuthController>();
      final signupData = signupProvider.data;
      final profilePhoto = signupProvider.profilePhoto;

      final success = await authController.register(
        email: signupData.email!,
        password: signupData.password!,
        userData: signupData.toJson(),
        profilePhoto: profilePhoto,
      );

      if (success) {
        // Pop back to home - MaterialApp's home Consumer will automatically
        // show MainScreen when authController.isAuthenticated becomes true
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authController.error ?? 'Registration failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

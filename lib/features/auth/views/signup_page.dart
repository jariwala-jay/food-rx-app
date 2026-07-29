import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/features/auth/models/signup_data.dart';
import 'package:flutter_app/features/auth/views/signup/basic_info_step.dart';
import 'package:flutter_app/features/auth/views/signup/health_info_step.dart';
import 'package:flutter_app/features/auth/views/signup/preferences_step.dart';
import 'package:flutter_app/features/auth/views/signup/other_details_step.dart';
import 'package:flutter_app/features/auth/views/signup/diet_plan_step.dart';
import 'package:flutter_app/features/auth/widgets/signup_progress_indicator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/providers/signup_provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/auth/widgets/signup_autofill_bridge.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({
    super.key,
    this.initialStep = 0,
    this.prefillData,
    this.isGoogleOnboarding = false,
  });

  /// Zero-based index to start the wizard at. Google users start at 1 (step 2).
  final int initialStep;

  /// Pre-populated data to seed into the SignupProvider (e.g. from Google).
  final SignupData? prefillData;

  /// When true the final submit patches the already-authenticated user's
  /// profile instead of calling the register endpoint.
  final bool isGoogleOnboarding;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  late int _currentStep;
  static const int _totalSteps = 5;
  final _autofillEmailController = TextEditingController();
  final _autofillPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;

    if (widget.prefillData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = context.read<SignupProvider>();
        final d = widget.prefillData!;
        provider.prefillForGoogle(
          name: d.name,
          email: d.email,
          profilePhotoUrl: d.profilePhotoUrl,
        );
      });
    }
  }

  @override
  void dispose() {
    _autofillEmailController.dispose();
    _autofillPasswordController.dispose();
    super.dispose();
  }

  void _syncAutofillBridge(SignupProvider signupProvider) {
    final email = signupProvider.data.email?.trim() ?? '';
    final password = signupProvider.data.password ?? '';
    _autofillEmailController.text = email;
    _autofillPasswordController.text = password;
  }

  void _handleNext() {
    setState(() {
      _currentStep++;
    });
  }

  void _handlePrevious() {
    setState(() {
      if (_currentStep > widget.initialStep) {
        _currentStep--;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (widget.isGoogleOnboarding) {
      await _handleGoogleOnboardingSubmit();
    } else {
      await _handleRegisterSubmit();
    }
  }

  Future<void> _handleRegisterSubmit() async {
    try {
      final signupProvider = context.read<SignupProvider>();
      final authController = context.read<AuthController>();
      final signupData = signupProvider.data;
      final profilePhoto = signupProvider.profilePhoto;
      _syncAutofillBridge(signupProvider);

      final success = await authController.register(
        email: signupData.email!,
        password: signupData.password!,
        userData: signupData.toJson(),
        profilePhoto: profilePhoto,
      );

      if (success) {
        TextInput.finishAutofillContext(shouldSave: true);
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } else {
        TextInput.finishAutofillContext(shouldSave: false);
        if (mounted) {
          final message =
              context.read<AuthController>().error ?? 'Registration failed';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      TextInput.finishAutofillContext(shouldSave: false);
      if (mounted) {
        final message = context.read<AuthController>().error ??
            'An error occurred. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleOnboardingSubmit() async {
    try {
      final signupProvider = context.read<SignupProvider>();
      final authController = context.read<AuthController>();
      final signupData = signupProvider.data;

      await authController.updateUserProfile(signupData.toJson());

      // Clearing the flag triggers a root rebuild: isAuthenticated=true and
      // pendingGoogleOnboarding=null → root shows MainScreen automatically.
      authController.clearGoogleOnboarding();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save your preferences. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
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
        child: AutofillGroup(
          child: Column(
            children: [
              SignupProgressIndicator(
                currentStep: _currentStep,
                totalSteps: _totalSteps,
              ),
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
              if (!widget.isGoogleOnboarding)
                SignupAutofillBridge(
                  emailController: _autofillEmailController,
                  passwordController: _autofillPasswordController,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

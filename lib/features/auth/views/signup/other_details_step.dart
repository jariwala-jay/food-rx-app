import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/features/auth/providers/signup_provider.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:flutter_app/core/services/personalization_service.dart';
import 'package:flutter_app/core/services/nutrition_content_loader.dart';
import 'package:provider/provider.dart';

class OtherDetailsStep extends StatefulWidget {
  final VoidCallback onPrevious;
  final VoidCallback onSubmit;

  const OtherDetailsStep({
    super.key,
    required this.onPrevious,
    required this.onSubmit,
  });

  @override
  State<OtherDetailsStep> createState() => _OtherDetailsStepState();
}

class _OtherDetailsStepState extends State<OtherDetailsStep> {
  final _formKey = GlobalKey<FormState>();
  final _cookingForPeopleController = TextEditingController();
  List<String> _selectedHealthGoals = [];
  String? _preferredMealPrepTime;
  String? _cookingSkill;
  bool _isLoading = false;

  final List<String> _healthGoals = [
    'Avoid diabetes',
    'Lower blood pressure',
    'Lower cholesterol',
    'Lower blood glucose (Sugar)',
    'Lose weight',
  ];

  final List<String> _mealPrepTimeOptions = [
    'Up to 15 minutes',
    'Up to 30 minutes',
    'Up to one hour',
  ];

  final List<String> _cookingSkillOptions = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void initState() {
    super.initState();
    final signupData = context.read<SignupProvider>().data;
    _selectedHealthGoals = List.from(signupData.healthGoals);
    _preferredMealPrepTime = signupData.preferredMealPrepTime;
    _cookingForPeopleController.text = signupData.cookingForPeople ?? '';
    _cookingSkill = signupData.cookingSkill;
  }

  @override
  void dispose() {
    _cookingForPeopleController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Required validations with neutral defaults
        if (_selectedHealthGoals.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one health goal'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        if (_preferredMealPrepTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select preferred meal prep time'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        if (_cookingForPeopleController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter how many people you cook for'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        if (_cookingSkill == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please rate your cooking skill'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        // Update other details in SignupProvider
        context.read<SignupProvider>().updateOtherDetails(
              healthGoals: _selectedHealthGoals,
              preferredMealPrepTime: _preferredMealPrepTime,
              cookingForPeople: _cookingForPeopleController.text.trim(),
              cookingSkill: _cookingSkill,
            );

        // Generate personalized diet plan
        final signupProvider = context.read<SignupProvider>();
        final signupData = signupProvider.data;

        try {
          // Load nutrition content and create personalization service
          final nutritionContent = await NutritionContentLoader.load();
          final personalizationService =
              PersonalizationService(nutritionContent);

          final personalizationResult = personalizationService.personalize(
            dob: signupData.dateOfBirth!,
            sex: signupData.sex!,
            heightFeet: signupData.heightFeet!,
            heightInches: signupData.heightInches!,
            weightLb: signupData.weight!,
            activityLevel: signupData.activityLevel!,
            medicalConditions: signupData.medicalConditions,
            healthGoals: signupData.healthGoals,
          );

          // Set the personalized diet plan
          signupProvider.setPersonalizedDietPlan(
            dietType: personalizationResult.dietType,
            targetCalories: personalizationResult.targetCalories,
            selectedDietPlan: personalizationResult.selectedDietPlan,
            diagnostics: personalizationResult.diagnostics,
          );

          if (kDebugMode) {
            print(
                'Generated personalized plan: ${personalizationResult.dietType} with ${personalizationResult.targetCalories} calories');
          }
        } catch (e) {
          // Fallback to simple diet type selection if personalization fails
          final bool isDashDiet =
              signupData.medicalConditions.contains('Hypertension') ||
                  signupData.healthGoals.contains('Lower blood pressure');
          signupProvider.setDietType(isDashDiet ? 'DASH' : 'MyPlate');

          if (kDebugMode) {
            print('Personalization failed, using fallback: $e');
          }
        }

        // Move to next step; actual registration happens at the end
        widget.onSubmit();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('An error occurred: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 200, left: 16, right: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Health Goal
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: AppCheckboxGroup(
                      label: 'Health Goals',
                      selectedValues: _selectedHealthGoals,
                      options: _healthGoals,
                      onChanged: (values) {
                        setState(() {
                          _selectedHealthGoals = values;
                        });
                      },
                    ),
                  ),
                  // Preferred Meal Prep time
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: AppRadioGroup<String>(
                      label: 'Preferred Meal Prep time',
                      value: _preferredMealPrepTime,
                      options: _mealPrepTimeOptions
                          .map((option) => {option: option})
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _preferredMealPrepTime = value;
                        });
                      },
                    ),
                  ),
                  // Cooking for how many people
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: AppFormField(
                      label: 'I am cooking for this many people',
                      hintText: 'Type Here',
                      controller: _cookingForPeopleController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  // Rate your Cooking Skill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: AppRadioGroup<String>(
                      label: 'Cooking Skill',
                      value: _cookingSkill,
                      options: _cookingSkillOptions
                          .map((option) => {option: option})
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _cookingSkill = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFF6A00)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: widget.onPrevious,
                        child: Text(
                          'Previous',
                          style: AppTypography.bg_16_sb
                              .copyWith(color: const Color(0xFFFF6A00)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6A00),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: AppTypography.bg_16_sb,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

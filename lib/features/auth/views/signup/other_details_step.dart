import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/utils/user_facing_errors.dart';
import 'package:flutter_app/features/auth/utils/signup_field_errors.dart';
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
  final _scrollController = ScrollController();
  final _healthGoalsSectionKey = GlobalKey();
  final _mealPrepSectionKey = GlobalKey();
  final _cookingForPeopleSectionKey = GlobalKey();
  final _cookingSkillSectionKey = GlobalKey();
  final _cookingForPeopleFocusNode = FocusNode();
  final _cookingForPeopleController = TextEditingController();
  List<String> _selectedHealthGoals = [];
  String? _preferredMealPrepTime;
  String? _cookingSkill;
  bool _isLoading = false;
  final _fieldErrors = SignupFieldErrors();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  final List<String> _healthGoals = [
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
    // Reset loading state when widget is initialized
    _isLoading = false;
    _fieldErrors.clearAll();

    final signupData = context.read<SignupProvider>().data;
    _selectedHealthGoals = List.from(signupData.healthGoals);
    _preferredMealPrepTime = signupData.preferredMealPrepTime;
    _cookingForPeopleController.text = signupData.cookingForPeople ?? '';
    _cookingSkill = signupData.cookingSkill;

    _cookingForPeopleController.addListener(() {
      if (_cookingForPeopleController.text.trim().isNotEmpty) {
        setState(() => _fieldErrors.clear('cookingForPeople'));
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cookingForPeopleFocusNode.dispose();
    _cookingForPeopleController.dispose();
    super.dispose();
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    final contextForKey = key.currentContext;
    if (contextForKey == null) return;
    await Scrollable.ensureVisible(
      contextForKey,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.2,
    );
  }

  Future<void> _handleSubmit() async {
    final isFormValid = _formKey.currentState!.validate();
    final hasMissingFields = _selectedHealthGoals.isEmpty ||
        _preferredMealPrepTime == null ||
        _cookingForPeopleController.text.trim().isEmpty ||
        _cookingSkill == null;

    if (!isFormValid || hasMissingFields) {
      setState(() {
        _fieldErrors.mark([
          if (_selectedHealthGoals.isEmpty) 'healthGoals',
          if (_preferredMealPrepTime == null) 'mealPrep',
          if (_cookingForPeopleController.text.trim().isEmpty)
            'cookingForPeople',
          if (_cookingSkill == null) 'cookingSkill',
        ]);
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });

      _formKey.currentState?.validate();

      if (_selectedHealthGoals.isEmpty) {
        await _scrollToKey(_healthGoalsSectionKey);
        return;
      }
      if (_preferredMealPrepTime == null) {
        await _scrollToKey(_mealPrepSectionKey);
        return;
      }
      if (_cookingForPeopleController.text.trim().isEmpty) {
        await _scrollToKey(_cookingForPeopleSectionKey);
        _cookingForPeopleFocusNode.requestFocus();
        return;
      }
      if (_cookingSkill == null) {
        await _scrollToKey(_cookingSkillSectionKey);
        return;
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _fieldErrors.clearAll();
    });

    try {
      context.read<SignupProvider>().updateOtherDetails(
            healthGoals: _selectedHealthGoals,
            preferredMealPrepTime: _preferredMealPrepTime,
            cookingForPeople: _cookingForPeopleController.text.trim(),
            cookingSkill: _cookingSkill,
          );

      final signupProvider = context.read<SignupProvider>();
      final signupData = signupProvider.data;

      try {
        final nutritionContent = await NutritionContentLoader.load();
        final personalizationService = PersonalizationService(nutritionContent);

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

        signupProvider.setPersonalizedDietPlan(
          dietType: personalizationResult.dietType,
          myPlanType: personalizationResult.myPlanType,
          showGlycemicIndex: personalizationResult.showGlycemicIndex,
          targetCalories: personalizationResult.targetCalories,
          selectedDietPlan: personalizationResult.selectedDietPlan,
          diagnostics: personalizationResult.diagnostics,
        );

        if (kDebugMode) {
          print(
              'Generated personalized plan: ${personalizationResult.dietType} with ${personalizationResult.targetCalories} calories');
        }
      } catch (e) {
        final bool isDashDiet =
            signupData.medicalConditions.contains('Hypertension') ||
                signupData.healthGoals.contains('Lower blood pressure');
        signupProvider.setDietType(isDashDiet ? 'DASH' : 'MyPlate');

        if (kDebugMode) {
          print('Personalization failed, using fallback: $e');
        }
      }

      setState(() {
        _isLoading = false;
      });

      widget.onSubmit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingErrorMessage(e)),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Health Goal
                    Container(
                      key: _healthGoalsSectionKey,
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppCheckboxGroup(
                            label: 'Diet-related Health Goals',
                            selectedValues: _selectedHealthGoals,
                            options: _healthGoals,
                            onChanged: (values) {
                              setState(() {
                                _selectedHealthGoals = values;
                                if (values.isNotEmpty) {
                                  _fieldErrors.clear('healthGoals');
                                }
                              });
                            },
                          ),
                          if (_fieldErrors.show('healthGoals') &&
                              _selectedHealthGoals.isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Please select at least one health goal',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontFamily: 'BricolageGrotesque',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Preferred Meal Prep time
                    Container(
                      key: _mealPrepSectionKey,
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppRadioGroup<String>(
                            label: 'Preferred Meal Prep Time',
                            value: _preferredMealPrepTime,
                            options: _mealPrepTimeOptions
                                .map((option) => {option: option})
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _preferredMealPrepTime = value;
                                if (value != null) {
                                  _fieldErrors.clear('mealPrep');
                                }
                              });
                            },
                          ),
                          if (_fieldErrors.show('mealPrep') &&
                              _preferredMealPrepTime == null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Please select preferred meal prep time',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontFamily: 'BricolageGrotesque',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Cooking for how many people
                    Container(
                      key: _cookingForPeopleSectionKey,
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppFormField(
                            label:
                                'I am cooking for this many people (Including Yourself)',
                            hintText: 'Type Here',
                            controller: _cookingForPeopleController,
                            focusNode: _cookingForPeopleFocusNode,
                            keyboardType: TextInputType.number,
                          ),
                          if (_fieldErrors.show('cookingForPeople') &&
                              _cookingForPeopleController.text
                                  .trim()
                                  .isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Please enter how many people you cook for',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontFamily: 'BricolageGrotesque',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Rate your Cooking Skill
                    Container(
                      key: _cookingSkillSectionKey,
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppRadioGroup<String>(
                            label: 'Rate Your Cooking Skills',
                            value: _cookingSkill,
                            options: _cookingSkillOptions
                                .map((option) => {option: option})
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _cookingSkill = value;
                                if (value != null) {
                                  _fieldErrors.clear('cookingSkill');
                                }
                              });
                            },
                          ),
                          if (_fieldErrors.show('cookingSkill') &&
                              _cookingSkill == null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Please rate your cooking skill',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontFamily: 'BricolageGrotesque',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
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
                        onPressed: () {
                          // Always allow going back, but reset loading state first
                          if (_isLoading) {
                            setState(() {
                              _isLoading = false;
                              _fieldErrors.clearAll();
                            });
                          }
                          widget.onPrevious();
                        },
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
        ],
      ),
    );
  }
}

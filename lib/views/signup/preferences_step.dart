import 'package:flutter/material.dart';
import 'package:flutter_app/providers/signup_provider.dart';
import 'package:flutter_app/widgets/form_fields.dart';
import 'package:flutter_app/utils/typography.dart';
import 'package:provider/provider.dart';
import 'diet_plan_step.dart';

class PreferencesStep extends StatefulWidget {
  final VoidCallback onPrevious;
  final VoidCallback onSubmit;

  const PreferencesStep({
    super.key,
    required this.onPrevious,
    required this.onSubmit,
  });

  @override
  State<PreferencesStep> createState() => _PreferencesStepState();
}

class _PreferencesStepState extends State<PreferencesStep> {
  final _formKey = GlobalKey<FormState>();
  List<String> _selectedFoodAllergies = [];
  String? _activityLevel;
  List<String> _selectedHealthGoals = [];

  final List<String> _activityLevels = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
  ];

  final List<String> _healthGoals = [
    'Avoid diabetes',
    'Lower blood pressure',
    'Lower cholesterol',
    'Lower blood glucose (Sugar)',
    'Lose weight',
  ];

  @override
  void initState() {
    super.initState();
    final signupData = context.read<SignupProvider>().data;
    _selectedFoodAllergies = List.from(signupData.foodAllergies);
    _activityLevel = signupData.activityLevel;
    _selectedHealthGoals = List.from(signupData.healthGoals);
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
                  const Text('Your Preferences', style: AppTypography.bg_24_b),
                  Text(
                    'Help us understand your preferences for personalized recommendations',
                    style: AppTypography.bg_14_r
                        .copyWith(color: const Color(0xFF90909A)),
                  ),
                  const SizedBox(height: 24),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppDropdownField(
                          label: 'Food Allergies',
                          value: null,
                          options: const [
                            'Tree Nuts',
                            'Peanuts',
                            'Dairy',
                            'Eggs',
                            'Soy',
                            'Wheat',
                            'Fish',
                            'Shellfish',
                            'None',
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                if (value == 'None') {
                                  _selectedFoodAllergies = [];
                                } else if (!_selectedFoodAllergies
                                    .contains(value)) {
                                  _selectedFoodAllergies.add(value);
                                }
                              });
                            }
                          },
                          hintText: 'Food Allergies',
                        ),
                        if (_selectedFoodAllergies.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          AppChipGroup(
                            values: _selectedFoodAllergies,
                            onChanged: (values) {
                              setState(() {
                                _selectedFoodAllergies = values;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
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
                      label: 'How physically active are you?',
                      value: _activityLevel,
                      options: _activityLevels
                          .map((level) => {level: level})
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _activityLevel = value;
                        });
                      },
                    ),
                  ),
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
                      label: 'Health Goal',
                      selectedValues: _selectedHealthGoals,
                      options: _healthGoals,
                      onChanged: (values) {
                        setState(() {
                          _selectedHealthGoals = values;
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
                        onPressed: () {
                          if (_formKey.currentState?.validate() ?? false) {
                            context.read<SignupProvider>().updatePreferences(
                                  foodAllergies: _selectedFoodAllergies,
                                  activityLevel: _activityLevel,
                                  healthGoals: _selectedHealthGoals,
                                );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DietPlanStep(
                                  onFinish: widget.onSubmit,
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text(
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

import 'package:flutter/material.dart';
import 'package:flutter_app/features/auth/providers/signup_provider.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:provider/provider.dart';

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
  // New preference fields
  List<String> _favoriteCuisines = [];
  String? _dailyFruitIntake;
  String? _dailyVegetableIntake;
  String? _dailyWaterIntake;
  bool _isLoading = false;
  bool _showErrors = false;

  final List<String> _activityLevels = [
    'Not Active',
    'Light',
    'Moderate',
    'Very Active',
  ];

  // Health goals are collected in Other Details step

  final List<String> _cuisineOptions = [
    "No preference",
    'American',
    'Mexican',
    'Italian',
    'Indian',
    'Chinese',
    'Thai',
    'Mediterranean',
    'Middle Eastern',
    'Japanese',
    'Korean',
    'Vietnamese',
    'Greek',
    'French',
    'Spanish',
  ];

  final List<String> _dailyIntakeOptions = [
    '0 servings',
    '1 serving',
    '2 servings',
    '3 servings',
    '4 servings',
    '5+ servings',
  ];

  @override
  void initState() {
    super.initState();
    final signupData = context.read<SignupProvider>().data;
    _selectedFoodAllergies = List.from(signupData.foodAllergies);
    _activityLevel = signupData.activityLevel;
    _favoriteCuisines = List.from(signupData.favoriteCuisines);
    _dailyFruitIntake = signupData.dailyFruitIntake;
    _dailyVegetableIntake = signupData.dailyVegetableIntake;
    _dailyWaterIntake = signupData.dailyWaterIntake;
  }

  Future<void> _handleSubmit() async {
    // Collect all validation errors first in the correct order (as they appear on screen)
    final List<String> missingFields = [];

    // Validate form fields
    final isFormValid = _formKey.currentState!.validate();

    // Check all required fields in the order they appear on screen
    // 1. Favorite Cuisines
    if (_favoriteCuisines.isEmpty) {
      missingFields.add('Favorite cuisines (or "No preference")');
    }
    // 2. Food Allergies
    if (_selectedFoodAllergies.isEmpty) {
      missingFields.add('Food allergies (or "No allergies" if you have none)');
    }
    // 3. Daily Fruit Intake
    if (_dailyFruitIntake == null) {
      missingFields.add('Daily fruit intake');
    }
    // 4. Daily Vegetable Intake
    if (_dailyVegetableIntake == null) {
      missingFields.add('Daily vegetable intake');
    }
    // 5. Daily Water Intake
    if (_dailyWaterIntake == null) {
      missingFields.add('Daily water intake');
    }
    // 6. Activity Level
    if (_activityLevel == null) {
      missingFields.add('Activity level');
    }

    // If there are any missing fields or form validation failed, show all errors
    if (!isFormValid || missingFields.isNotEmpty) {
      // Show errors on fields
      setState(() {
        _showErrors = true;
      });

      // Trigger form validation to show field errors
      _formKey.currentState?.validate();

      // Show all missing fields in one message
      if (missingFields.isNotEmpty) {
        final errorMessage = missingFields.length == 1
            ? 'Please fill in: ${missingFields.first}'
            : 'Please fill in the following required fields:\n• ${missingFields.join('\n• ')}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _showErrors = false;
    });

    try {
      // Note: Favorite cuisines is now required, so we don't set a default here

      // Update preferences in SignupProvider
      context.read<SignupProvider>().updatePreferences(
            foodAllergies: _selectedFoodAllergies,
            activityLevel: _activityLevel,
            favoriteCuisines: _favoriteCuisines,
            dailyFruitIntake: _dailyFruitIntake,
            dailyVegetableIntake: _dailyVegetableIntake,
            dailyWaterIntake: _dailyWaterIntake,
          );

      // Advance to next step
      widget.onSubmit();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
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
                  const Text('Your Preferences', style: AppTypography.bg_24_b),
                  Text(
                    'Help us understand your preferences for personalized recommendations',
                    style: AppTypography.bg_14_r
                        .copyWith(color: const Color(0xFF90909A)),
                  ),
                  const SizedBox(height: 24),
                  // Favorite Cuisines (multi-select modal)
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
                          label: 'Favorite',
                          value: null,
                          options: _cuisineOptions,
                          onChanged: (_) {},
                          hintText: 'Select cuisines',
                          showSearchBar: true,
                          multiSelect: true,
                          selectedValues: _favoriteCuisines,
                          onChangedMulti: (values) {
                            setState(() {
                              _favoriteCuisines = values;
                              _showErrors = false;
                            });
                          },
                        ),
                        if (_favoriteCuisines.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          AppChipGroup(
                            values: _favoriteCuisines,
                            onChanged: (values) {
                              setState(() {
                                _favoriteCuisines = values;
                                _showErrors = false;
                              });
                            },
                          ),
                        ],
                        if (_showErrors && _favoriteCuisines.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Please select your favorite cuisines (or "No preference")',
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
                  // Food Allergies (multi-select modal)
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
                            'No allergies',
                            'Tree Nuts',
                            'Peanuts',
                            'Dairy',
                            'Eggs',
                            'Soy',
                            'Wheat',
                            'Fish',
                            'Shellfish',
                          ],
                          onChanged: (_) {},
                          hintText: 'Food Allergies',
                          showSearchBar: true,
                          multiSelect: true,
                          selectedValues: _selectedFoodAllergies,
                          onChangedMulti: (values) {
                            setState(() {
                              // Allow explicit 'No allergies' as a value but not with others
                              if (values.contains('No allergies')) {
                                _selectedFoodAllergies = ['No allergies'];
                              } else {
                                _selectedFoodAllergies = values;
                              }
                              _showErrors = false;
                            });
                          },
                        ),
                        if (_selectedFoodAllergies.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          AppChipGroup(
                            values: _selectedFoodAllergies,
                            onChanged: (values) {
                              setState(() {
                                // Respect 'No allergies' exclusivity
                                if (values.contains('No allergies') &&
                                    values.length > 1) {
                                  _selectedFoodAllergies = ['No allergies'];
                                } else {
                                  _selectedFoodAllergies = values;
                                }
                                _showErrors = false;
                              });
                            },
                          ),
                        ],
                        if (_showErrors && _selectedFoodAllergies.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Please select your food allergies (or "No allergies" if you have none)',
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

                  // Daily Intake (Fruit & Vegetable)
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
                        const Text('Daily Intake',
                            style: AppTypography.bg_16_m),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: AppDropdownField(
                                value: _dailyFruitIntake,
                                options: _dailyIntakeOptions,
                                onChanged: (value) {
                                  setState(() {
                                    _dailyFruitIntake = value;
                                    _showErrors = false;
                                  });
                                },
                                hintText: 'Fruit',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AppDropdownField(
                                value: _dailyVegetableIntake,
                                options: _dailyIntakeOptions,
                                onChanged: (value) {
                                  setState(() {
                                    _dailyVegetableIntake = value;
                                    _showErrors = false;
                                  });
                                },
                                hintText: 'Vegetable',
                              ),
                            ),
                          ],
                        ),
                        if (_showErrors &&
                            (_dailyFruitIntake == null ||
                                _dailyVegetableIntake == null)) ...[
                          const SizedBox(height: 8),
                          Text(
                            _dailyFruitIntake == null &&
                                    _dailyVegetableIntake == null
                                ? 'Please select daily fruit and vegetable intake'
                                : _dailyFruitIntake == null
                                    ? 'Please select daily fruit intake'
                                    : 'Please select daily vegetable intake',
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
                  // Daily Water Intake (Radio)
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
                        AppRadioGroup<String>(
                          label: 'Daily Water Intake',
                          value: _dailyWaterIntake,
                          options: const [
                            {'0 glass': '0 glass'},
                            {
                              'less than 8 glasses (64 oz)':
                                  'less than 8 glasses (64 oz)'
                            },
                            {
                              '8 or more glasses (64 oz)':
                                  '8 or more glasses (64 oz)'
                            },
                          ],
                          onChanged: (value) {
                            setState(() {
                              _dailyWaterIntake = value;
                              _showErrors = false;
                            });
                          },
                        ),
                        if (_showErrors && _dailyWaterIntake == null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Please select daily water intake',
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
                  // Activity Level
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
                        AppRadioGroup<String>(
                          label: 'How physically active are you?',
                          value: _activityLevel,
                          options: _activityLevels
                              .map((level) => {level: level})
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _activityLevel = value;
                              _showErrors = false;
                            });
                          },
                        ),
                        if (_showErrors && _activityLevel == null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Please select your activity level',
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
                                'Next',
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

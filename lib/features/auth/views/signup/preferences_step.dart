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
  List<String> _selectedFavoriteCuisines = [];
  final _dailyFruitIntakeController = TextEditingController();
  final _dailyVegetableIntakeController = TextEditingController();
  String? _dailyWaterIntake;
  bool _isLoading = false;

  final List<String> _activityLevels = [
    'Not Active',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
  ];

  final List<String> _cuisines = [
    'American',
    'Mexican',
    'Italian',
    'Chinese',
    'Indian',
    'French',
    'Thai',
    'Japanese',
    'Mediterranean',
    'Korean',
  ];

  final List<String> _waterIntakeOptions = [
    '0 glasses',
    'Less than 8 glasses',
    '8 or more glasses',
  ];

  @override
  void initState() {
    super.initState();
    final signupData = context.read<SignupProvider>().data;
    _selectedFoodAllergies = List.from(signupData.foodAllergies);
    _activityLevel = signupData.activityLevel;
    _selectedFavoriteCuisines = List.from(signupData.favoriteCuisines);
    _dailyFruitIntakeController.text = signupData.dailyFruitIntake ?? '';
    _dailyVegetableIntakeController.text =
        signupData.dailyVegetableIntake ?? '';
    _dailyWaterIntake = signupData.dailyWaterIntake;
  }

  @override
  void dispose() {
    _dailyFruitIntakeController.dispose();
    _dailyVegetableIntakeController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (_formKey.currentState!.validate()) {
      // Update preferences in SignupProvider
      context.read<SignupProvider>().updatePreferences(
            foodAllergies: _selectedFoodAllergies,
            activityLevel: _activityLevel,
            favoriteCuisines: _selectedFavoriteCuisines,
            dailyFruitIntake: _dailyFruitIntakeController.text.trim(),
            dailyVegetableIntake: _dailyVegetableIntakeController.text.trim(),
            dailyWaterIntake: _dailyWaterIntake,
          );

      widget.onSubmit();
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
                  // Favorite Cuisines
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
                          options: _cuisines,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                if (!_selectedFavoriteCuisines
                                    .contains(value)) {
                                  _selectedFavoriteCuisines.add(value);
                                }
                              });
                            }
                          },
                          hintText: 'Select Cuisines',
                        ),
                        if (_selectedFavoriteCuisines.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          AppChipGroup(
                            values: _selectedFavoriteCuisines,
                            onChanged: (values) {
                              setState(() {
                                _selectedFavoriteCuisines = values;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Food Allergies
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
                  // Daily Intake
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
                        const Text(
                          'Daily Intake',
                          style: AppTypography.bg_16_m,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: AppFormField(
                                hintText: 'Fruits',
                                controller: _dailyFruitIntakeController,
                                keyboardType: TextInputType.text,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AppFormField(
                                hintText: 'Vegetables',
                                controller: _dailyVegetableIntakeController,
                                keyboardType: TextInputType.text,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Daily Water Intake
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
                    child: AppDropdownField(
                      label: 'Daily Water Intake',
                      value: _dailyWaterIntake,
                      options: _waterIntakeOptions,
                      onChanged: (value) {
                        setState(() {
                          _dailyWaterIntake = value;
                        });
                      },
                      hintText: 'Select Water Intake',
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
                        onPressed: _isLoading ? null : _handleNext,
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

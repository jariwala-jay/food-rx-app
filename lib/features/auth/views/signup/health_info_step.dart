import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/features/auth/providers/signup_provider.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class HealthInfoStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const HealthInfoStep({
    super.key,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<HealthInfoStep> createState() => _HealthInfoStepState();
}

class _HealthInfoStepState extends State<HealthInfoStep> {
  final _formKey = GlobalKey<FormState>();
  final _dobController = TextEditingController();
  final _weightController = TextEditingController();
  String? _selectedSex;
  double? _heightFeet;
  double? _heightInches;
  List<String> _selectedMedicalConditions = [];
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final signupData = context.read<SignupProvider>().data;
    _dobController.text =
        signupData.dateOfBirth?.toString().split(' ')[0] ?? '';
    _selectedSex = signupData.sex;
    _heightFeet = signupData.heightFeet;
    _heightInches = signupData.heightInches;
    _weightController.text = signupData.weight?.toString() ?? '';
    _selectedMedicalConditions = List.from(signupData.medicalConditions);
  }

  @override
  void dispose() {
    _dobController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF6A00),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2C2C2C),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to MyFoodRx!',
                      style: AppTypography.bg_24_b,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This app is designed to give you a personalized approach to maximize the benefits of using food as medicine to improve your health. Please provide the information requested below. This information will be use to provide you with a personalized plan and resources to best meet your needs.',
                      style: AppTypography.bg_14_r,
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 16),
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
                        label: 'Date of birth',
                        hintText: 'MM/DD/YYYY',
                        controller: _dobController,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          color: Color(0xFF90909A),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your date of birth';
                          }
                          return null;
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppRadioGroup<String>(
                            label: 'Sex',
                            value: _selectedSex,
                            options: const [
                              {'male': 'Male'},
                              {'female': 'Female'},
                              {'intersex': 'Intersex'},
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedSex = value;
                                _showErrors = false;
                              });
                            },
                          ),
                          if (_showErrors && _selectedSex == null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Please select your sex',
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
                          const Text('Height', style: AppTypography.bg_16_m),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: HeightDropdownField(
                                  label: '',
                                  value: _heightFeet?.toString(),
                                  options: List.generate(
                                      8, (i) => (i + 4).toString()),
                                  onChanged: (value) {
                                    setState(() {
                                      _heightFeet =
                                          double.tryParse(value ?? '');
                                      _showErrors = false;
                                    });
                                  },
                                  hintText: 'FT',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: HeightDropdownField(
                                  label: '',
                                  value: _heightInches?.toString(),
                                  options:
                                      List.generate(12, (i) => i.toString()),
                                  onChanged: (value) {
                                    setState(() {
                                      _heightInches =
                                          double.tryParse(value ?? '');
                                      _showErrors = false;
                                    });
                                  },
                                  hintText: 'INCH',
                                ),
                              ),
                            ],
                          ),
                          if (_showErrors &&
                              (_heightFeet == null ||
                                  _heightInches == null)) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Please select your height',
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
                        label: 'Weight',
                        hintText: 'Enter Weight',
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _dismissKeyboard(),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your weight';
                          }
                          final weight = double.tryParse(value);
                          if (weight == null) {
                            return 'Please enter a valid number';
                          }
                          if (weight <= 0) {
                            return 'Weight must be greater than 0';
                          }
                          if (weight < 50 || weight > 1000) {
                            return 'Please enter a weight between 50 and 1000 lbs';
                          }
                          return null;
                        },
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'LB',
                            style: AppTypography.bg_14_r
                                .copyWith(color: const Color(0xFF90909A)),
                          ),
                        ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppDropdownField(
                            label: 'Diet-related Chronic Condition',
                            value: null,
                            options: const [
                              'Hypertension',
                              'Pre-Diabetes',
                              'Diabetes',
                              'Overweight/Obesity',
                              'Other',
                            ],
                            multiSelect: true,
                            selectedValues: _selectedMedicalConditions,
                            onChangedMulti: (values) {
                              setState(() {
                                // Allow explicit 'None' as a value but not with others
                                if (values.contains('None')) {
                                  _selectedMedicalConditions = ['None'];
                                } else {
                                  _selectedMedicalConditions = values;
                                }
                                _showErrors = false;
                              });
                            },
                            onChanged: (_) {},
                            hintText: 'Select Disease',
                          ),
                          if (_selectedMedicalConditions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            AppChipGroup(
                              values: _selectedMedicalConditions,
                              onChanged: (values) {
                                setState(() {
                                  // Respect 'None' exclusivity
                                  if (values.contains('None') &&
                                      values.length > 1) {
                                    _selectedMedicalConditions = ['None'];
                                  } else {
                                    _selectedMedicalConditions = values;
                                  }
                                  _showErrors = false;
                                });
                              },
                            ),
                          ],
                          if (_showErrors &&
                              _selectedMedicalConditions.isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Please select your medical conditions (or None)',
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
                          onPressed: () {
                            // Collect all validation errors first in the correct order
                            final List<String> missingFields = [];

                            // Validate form fields (date of birth, weight)
                            final isFormValid =
                                _formKey.currentState!.validate();

                            // Check all required fields in the order they appear on screen
                            if (_dobController.text.trim().isEmpty) {
                              missingFields.add('Date of birth');
                            }
                            if (_selectedSex == null) {
                              missingFields.add('Sex');
                            }
                            if (_heightFeet == null || _heightInches == null) {
                              missingFields.add('Height');
                            }
                            if (_weightController.text.trim().isEmpty) {
                              missingFields.add('Weight');
                            }
                            if (_selectedMedicalConditions.isEmpty) {
                              missingFields
                                  .add('Diet-related Chronic Condition');
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

                            try {
                              // Clear error state
                              setState(() {
                                _showErrors = false;
                              });

                              final dateOfBirth = _dobController.text.isNotEmpty
                                  ? DateFormat('MM/dd/yyyy')
                                      .parse(_dobController.text)
                                  : null;

                              context.read<SignupProvider>().updateHealthInfo(
                                    dateOfBirth: dateOfBirth,
                                    sex: _selectedSex,
                                    heightFeet: _heightFeet,
                                    heightInches: _heightInches,
                                    weight:
                                        double.tryParse(_weightController.text),
                                    medicalConditions:
                                        _selectedMedicalConditions,
                                  );
                              widget.onNext();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid date'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: const Text(
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
      ),
    );
  }
}

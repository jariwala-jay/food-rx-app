import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/providers/signup_provider.dart';
import 'package:flutter_app/widgets/form_fields.dart';
import 'package:flutter_app/utils/typography.dart';
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
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Health Information',
                      style: AppTypography.bg_24_b),
                  Text(
                    'Please provide your health details for better recommendations',
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
                    child: AppRadioGroup<String>(
                      label: 'Sex',
                      value: _selectedSex,
                      options: const [
                        {'male': 'Male'},
                        {'female': 'Female'},
                        {'decline': 'Decline to answer'},
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSex = value;
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
                                options:
                                    List.generate(8, (i) => (i + 4).toString()),
                                onChanged: (value) {
                                  setState(() {
                                    _heightFeet = double.tryParse(value ?? '');
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
                                options: List.generate(12, (i) => i.toString()),
                                onChanged: (value) {
                                  setState(() {
                                    _heightInches =
                                        double.tryParse(value ?? '');
                                  });
                                },
                                hintText: 'INCH',
                              ),
                            ),
                          ],
                        ),
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
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
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
                          label: 'Medical Conditions',
                          value: null,
                          options: const [
                            'Hypertension',
                            'Pre-Diabetes',
                            'Diabetes',
                            'Overweight/Obesity',
                            'None',
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                if (value == 'None') {
                                  _selectedMedicalConditions = [];
                                } else if (!_selectedMedicalConditions
                                    .contains(value)) {
                                  _selectedMedicalConditions.add(value);
                                }
                              });
                            }
                          },
                          hintText: 'Select Disease',
                        ),
                        if (_selectedMedicalConditions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          AppChipGroup(
                            values: _selectedMedicalConditions,
                            onChanged: (values) {
                              setState(() {
                                _selectedMedicalConditions = values;
                              });
                            },
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
                          if (_formKey.currentState!.validate()) {
                            try {
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
    );
  }
}

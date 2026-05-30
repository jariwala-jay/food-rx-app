import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/features/auth/providers/signup_provider.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:flutter_app/features/auth/utils/signup_field_errors.dart';
import 'package:flutter_app/features/auth/widgets/signup_date_picker.dart';
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
  final _scrollController = ScrollController();
  final _dobSectionKey = GlobalKey();
  final _sexSectionKey = GlobalKey();
  final _heightSectionKey = GlobalKey();
  final _weightSectionKey = GlobalKey();
  final _conditionSectionKey = GlobalKey();
  final _weightFocusNode = FocusNode();
  final _dobController = TextEditingController();
  final _weightController = TextEditingController();
  String? _selectedSex;
  double? _heightFeet;
  double? _heightInches;
  List<String> _selectedMedicalConditions = [];
  final _fieldErrors = SignupFieldErrors();
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  static final _dobDisplayFormat = DateFormat('MM/dd/yyyy');
  static final _dobIsoFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final signupData = context.read<SignupProvider>().data;
    _dobController.text = _formatDobForDisplay(signupData.dateOfBirth);
    _selectedSex = signupData.sex;
    _heightFeet = signupData.heightFeet;
    _heightInches = signupData.heightInches;
    _weightController.text = signupData.weight?.toString() ?? '';
    _selectedMedicalConditions = List.from(signupData.medicalConditions);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _weightFocusNode.dispose();
    _dobController.dispose();
    _weightController.dispose();
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

  String _formatDobForDisplay(DateTime? date) {
    if (date == null) return '';
    return _dobDisplayFormat.format(date);
  }

  DateTime? _parseDobText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    for (final format in [_dobDisplayFormat, _dobIsoFormat]) {
      try {
        return format.parseStrict(trimmed);
      } catch (_) {}
    }
    return null;
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final fallbackInitialDate = DateTime(now.year - 40, 1, 1);
    DateTime initialDate = fallbackInitialDate;

    final parsedDob = _parseDobText(_dobController.text);
    if (parsedDob != null && !parsedDob.isAfter(now)) {
      initialDate = parsedDob;
    }

    final DateTime? picked = await showSignupDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _dobController.text = _formatDobForDisplay(picked);
        _fieldErrors.clear('dob');
      });
      if (_autovalidateMode == AutovalidateMode.onUserInteraction) {
        _formKey.currentState?.validate();
      }
    }
  }

  bool _isAtLeast18(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age >= 18;
  }

  String? _validateDob(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your date of birth';
    }
    final dob = _parseDobText(value);
    if (dob == null) {
      return 'Please enter a valid date of birth';
    }
    if (!_isAtLeast18(dob)) {
      return 'You must be at least 18 years old';
    }
    return null;
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
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
                    Container(
                      key: _dobSectionKey,
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
                        validator: _validateDob,
                      ),
                    ),
                    Container(
                      key: _sexSectionKey,
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
                                if (value != null) _fieldErrors.clear('sex');
                              });
                            },
                          ),
                          if (_fieldErrors.show('sex') &&
                              _selectedSex == null) ...[
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
                      key: _heightSectionKey,
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
                                      if (_heightFeet != null &&
                                          _heightInches != null) {
                                        _fieldErrors.clear('height');
                                      }
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
                                      if (_heightFeet != null &&
                                          _heightInches != null) {
                                        _fieldErrors.clear('height');
                                      }
                                    });
                                  },
                                  hintText: 'INCH',
                                ),
                              ),
                            ],
                          ),
                          if (_fieldErrors.show('height') &&
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
                      key: _weightSectionKey,
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
                        focusNode: _weightFocusNode,
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
                      key: _conditionSectionKey,
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
                                if (_selectedMedicalConditions.isNotEmpty) {
                                  _fieldErrors.clear('conditions');
                                }
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
                                  if (_selectedMedicalConditions.isNotEmpty) {
                                    _fieldErrors.clear('conditions');
                                  }
                                });
                              },
                            ),
                          ],
                          if (_fieldErrors.show('conditions') &&
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
                          onPressed: () async {
                            final isFormValid =
                                _formKey.currentState!.validate();
                            final hasMissingFields =
                                _dobController.text.trim().isEmpty ||
                                    _selectedSex == null ||
                                    _heightFeet == null ||
                                    _heightInches == null ||
                                    _weightController.text.trim().isEmpty ||
                                    _selectedMedicalConditions.isEmpty;

                            if (!isFormValid || hasMissingFields) {
                              setState(() {
                                _fieldErrors.mark([
                                  if (_dobController.text.trim().isEmpty ||
                                      _validateDob(
                                              _dobController.text.trim()) !=
                                          null)
                                    'dob',
                                  if (_selectedSex == null) 'sex',
                                  if (_heightFeet == null ||
                                      _heightInches == null)
                                    'height',
                                  if (_selectedMedicalConditions.isEmpty)
                                    'conditions',
                                ]);
                                _autovalidateMode =
                                    AutovalidateMode.onUserInteraction;
                              });

                              _formKey.currentState?.validate();

                              if (_validateDob(_dobController.text.trim()) !=
                                  null) {
                                await _scrollToKey(_dobSectionKey);
                                return;
                              }
                              if (_selectedSex == null) {
                                await _scrollToKey(_sexSectionKey);
                                return;
                              }
                              if (_heightFeet == null || _heightInches == null) {
                                await _scrollToKey(_heightSectionKey);
                                return;
                              }
                              if (_weightController.text.trim().isEmpty) {
                                await _scrollToKey(_weightSectionKey);
                                _weightFocusNode.requestFocus();
                                return;
                              }
                              if (_selectedMedicalConditions.isEmpty) {
                                await _scrollToKey(_conditionSectionKey);
                                return;
                              }
                              return;
                            }

                            try {
                              setState(() {
                                _fieldErrors.clearAll();
                              });

                              final dateOfBirth =
                                  _parseDobText(_dobController.text);

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
        ],
      ),
    );
  }
}

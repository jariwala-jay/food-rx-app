import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:intl/intl.dart';

class ProfileEditPage extends StatefulWidget {
  final String fieldType;
  final dynamic currentValue;

  const ProfileEditPage({
    super.key,
    required this.fieldType,
    required this.currentValue,
  });

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _weightController = TextEditingController();
  String? _selectedValue;
  DateTime? _selectedDate;
  double? _heightFeet;
  double? _heightInches;
  double? _weight;
  String? _weightUnit;
  List<String> _selectedMultiValues = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeValues();
  }

  void _initializeValues() {
    switch (widget.fieldType) {
      case 'name':
      case 'email':
        _textController.text = widget.currentValue ?? '';
        break;
      case 'sex':
        // Handle both lowercase and original case
        _selectedValue = widget.currentValue?.toString().toLowerCase();
        break;
      case 'activityLevel':
        _selectedValue = widget.currentValue;
        break;
      case 'dateOfBirth':
        if (widget.currentValue is DateTime) {
          _selectedDate = widget.currentValue as DateTime;
          _textController.text =
              DateFormat('MM/dd/yyyy').format(_selectedDate!);
        }
        break;
      case 'height':
        if (widget.currentValue is Map) {
          final map = widget.currentValue as Map;
          _heightFeet = map['heightFeet']?.toDouble();
          _heightInches = map['heightInches']?.toDouble();
        }
        break;
      case 'weight':
        if (widget.currentValue is Map) {
          final map = widget.currentValue as Map;
          _weight = map['weight']?.toDouble();
          _weightUnit = map['weightUnit'] ?? 'lbs';
          if (_weight != null) {
            _weightController.text =
                _weight!.toStringAsFixed(_weight! % 1 == 0 ? 0 : 1);
          }
        }
        break;
      case 'medicalConditions':
      case 'healthGoals':
        if (widget.currentValue is List) {
          _selectedMultiValues = List<String>.from(widget.currentValue);
        }
        break;
      case 'allergies':
        if (widget.currentValue is List) {
          _selectedMultiValues = List<String>.from(widget.currentValue);
          // Convert legacy "None" to "No allergies" for consistency
          if (_selectedMultiValues.contains('None')) {
            _selectedMultiValues = _selectedMultiValues
                .map((item) => item == 'None' ? 'No allergies' : item)
                .toList();
            // If "None" was selected, ensure exclusivity
            if (_selectedMultiValues.contains('No allergies') &&
                _selectedMultiValues.length > 1) {
              _selectedMultiValues = ['No allergies'];
            }
          }
        }
        break;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ??
          DateTime.now().subtract(const Duration(days: 365 * 25)),
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
        _selectedDate = picked;
        _textController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authController = context.read<AuthController>();
      Map<String, dynamic> updates = {};

      switch (widget.fieldType) {
        case 'name':
          updates['name'] = _textController.text.trim();
          break;
        case 'email':
          updates['email'] = _textController.text.trim();
          break;
        case 'sex':
          if (_selectedValue != null) {
            updates['sex'] = _selectedValue;
            // Sex affects diet plan, trigger re-plan check
            _triggerReplanCheck();
          }
          break;
        case 'activityLevel':
          if (_selectedValue != null) {
            updates['activityLevel'] = _selectedValue;
            // Activity level affects diet plan, trigger re-plan check
            _triggerReplanCheck();
          }
          break;
        case 'dateOfBirth':
          if (_selectedDate != null) {
            updates['dateOfBirth'] = _selectedDate!.toIso8601String();
            // Also update age for consistency
            final now = DateTime.now();
            int age = now.year - _selectedDate!.year;
            if (now.month < _selectedDate!.month ||
                (now.month == _selectedDate!.month &&
                    now.day < _selectedDate!.day)) {
              age--;
            }
            updates['age'] = age;
            // Age affects diet plan, trigger re-plan check
            _triggerReplanCheck();
          }
          break;
        case 'height':
          if (_heightFeet != null && _heightInches != null) {
            updates['heightFeet'] = _heightFeet;
            updates['heightInches'] = _heightInches;
            updates['heightUnit'] = 'inches';
            // Calculate total height in inches
            updates['height'] = (_heightFeet! * 12) + _heightInches!;
            // Height affects diet plan, trigger re-plan check
            _triggerReplanCheck();
          }
          break;
        case 'weight':
          if (_weightController.text.isNotEmpty) {
            final weightValue = double.tryParse(_weightController.text);
            if (weightValue != null) {
              updates['weight'] = weightValue;
              updates['weightUnit'] = _weightUnit ?? 'lbs';
              // Weight affects diet plan, trigger re-plan check
              _triggerReplanCheck();
            }
          }
          break;
        case 'medicalConditions':
          updates['medicalConditions'] = _selectedMultiValues;
          // Medical conditions affect diet plan, trigger re-plan check
          _triggerReplanCheck();
          break;
        case 'healthGoals':
          updates['healthGoals'] = _selectedMultiValues;
          // Health goals affect diet plan, trigger re-plan check
          _triggerReplanCheck();
          break;
        case 'allergies':
          updates['allergies'] = _selectedMultiValues;
          break;
      }

      if (updates.isNotEmpty) {
        await authController.updateUserProfile(updates);
        if (mounted) {
          // Check if re-planning is needed (diet-affecting fields)
          final needsReplan = [
            'sex',
            'dateOfBirth',
            'height',
            'weight',
            'activityLevel',
            'medicalConditions',
            'healthGoals',
          ].contains(widget.fieldType);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(needsReplan
                  ? 'Updated successfully. Your diet plan may be recalculated.'
                  : 'Updated successfully'),
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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

  void _triggerReplanCheck() {
    // Note: The AuthController's updateUserProfile already checks for re-plan triggers
    // This is just a marker that this field affects diet planning
    // The actual re-plan check happens in AuthController.updateUserProfile()
  }

  String _getFieldTitle() {
    switch (widget.fieldType) {
      case 'name':
        return 'Edit Name';
      case 'email':
        return 'Edit Email';
      case 'sex':
        return 'Edit Sex';
      case 'activityLevel':
        return 'Edit Activity Level';
      case 'dateOfBirth':
        return 'Edit Date of Birth';
      case 'height':
        return 'Edit Height';
      case 'weight':
        return 'Edit Weight';
      case 'medicalConditions':
        return 'Edit Diet-related Chronic Condition';
      case 'healthGoals':
        return 'Edit Diet-related Health Goals';
      case 'allergies':
        return 'Edit Allergies';
      default:
        return 'Edit';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: Text(_getFieldTitle()),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: AppTypography.bg_16_sb,
                    ),
                  ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildEditWidget(),
        ),
      ),
    );
  }

  Widget _buildEditWidget() {
    switch (widget.fieldType) {
      case 'name':
      case 'email':
        return _buildTextEdit();
      case 'sex':
        return _buildSexEdit();
      case 'activityLevel':
        return _buildActivityLevelEdit();
      case 'dateOfBirth':
        return _buildDateOfBirthEdit();
      case 'height':
        return _buildHeightEdit();
      case 'weight':
        return _buildWeightEdit();
      case 'medicalConditions':
        return _buildMedicalConditionsEdit();
      case 'healthGoals':
        return _buildHealthGoalsEdit();
      case 'allergies':
        return _buildAllergiesEdit();
      default:
        return const Text('Edit not implemented');
    }
  }

  Widget _buildTextEdit() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppFormField(
        label: widget.fieldType == 'name' ? 'Name' : 'Email',
        hintText:
            widget.fieldType == 'name' ? 'Enter your name' : 'Enter your email',
        controller: _textController,
        keyboardType: widget.fieldType == 'email'
            ? TextInputType.emailAddress
            : TextInputType.text,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'This field is required';
          }
          if (widget.fieldType == 'email') {
            if (!value.contains('@') || !value.contains('.')) {
              return 'Please enter a valid email';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSexEdit() {
    // Map to handle case-insensitive matching
    String? currentValue = _selectedValue;
    if (currentValue != null) {
      final lower = currentValue.toLowerCase();
      if (lower == 'male') {
        currentValue = 'male';
      } else if (lower == 'female') {
        currentValue = 'female';
      } else if (lower == 'decline') {
        currentValue = 'decline';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppRadioGroup<String>(
        label: 'Sex',
        value: currentValue,
        options: const [
          {'male': 'Male'},
          {'female': 'Female'},
          {'intersex': 'Intersex'},
        ],
        onChanged: (value) {
          setState(() {
            _selectedValue = value;
          });
        },
      ),
    );
  }

  Widget _buildActivityLevelEdit() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppRadioGroup<String>(
        label: 'Activity Level',
        value: _selectedValue,
        options: const [
          {'Not Active': 'Not Active'},
          {'Seldom Active': 'Seldom Active'},
          {'Moderately Active': 'Moderately Active'},
          {'Very Active': 'Very Active'},
        ],
        onChanged: (value) {
          setState(() {
            _selectedValue = value;
          });
        },
      ),
    );
  }

  Widget _buildDateOfBirthEdit() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppFormField(
        label: 'Date of Birth',
        hintText: 'MM/DD/YYYY',
        controller: _textController,
        readOnly: true,
        onTap: () => _selectDate(context),
        suffixIcon: const Icon(
          Icons.calendar_today_outlined,
          color: Color(0xFF90909A),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a date of birth';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildHeightEdit() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  options: List.generate(8, (i) => (i + 4).toString()),
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
                      _heightInches = double.tryParse(value ?? '');
                    });
                  },
                  hintText: 'INCH',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightEdit() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppFormField(
            label: 'Weight',
            hintText: 'Enter Weight',
            controller: _weightController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            suffixIcon: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _weightUnit = 'lbs';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (_weightUnit ?? 'lbs') == 'lbs'
                            ? const Color(0xFFFF6A00)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'lbs',
                        style: AppTypography.bg_14_r.copyWith(
                          color: (_weightUnit ?? 'lbs') == 'lbs'
                              ? Colors.white
                              : const Color(0xFF90909A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _weightUnit = 'kg';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _weightUnit == 'kg'
                            ? const Color(0xFFFF6A00)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'kg',
                        style: AppTypography.bg_14_r.copyWith(
                          color: _weightUnit == 'kg'
                              ? Colors.white
                              : const Color(0xFF90909A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your weight';
              }
              if (double.tryParse(value) == null) {
                return 'Please enter a valid number';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalConditionsEdit() {
    final options = const [
      'Hypertension',
      'Pre-Diabetes',
      'Diabetes',
      'Overweight/Obesity',
      'None',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDropdownField(
            label: 'Diet-related Chronic Condition',
            value: null,
            options: options,
            onChanged: (_) {},
            hintText: 'Select Diet-related Chronic Condition',
            showSearchBar: true,
            multiSelect: true,
            selectedValues: _selectedMultiValues,
            onChangedMulti: (values) {
              setState(() {
                if (values.contains('Other')) {
                  _selectedMultiValues = ['Other'];
                } else {
                  _selectedMultiValues = values;
                }
              });
            },
          ),
          if (_selectedMultiValues.isNotEmpty) ...[
            const SizedBox(height: 16),
            AppChipGroup(
              values: _selectedMultiValues,
              onChanged: (values) {
                setState(() {
                  if (values.contains('Other') && values.length > 1) {
                    _selectedMultiValues = ['Other'];
                  } else {
                    _selectedMultiValues = values;
                  }
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllergiesEdit() {
    final options = const [
      'No allergies',
      'Tree Nuts',
      'Peanuts',
      'Dairy',
      'Eggs',
      'Soy',
      'Wheat',
      'Fish',
      'Shellfish',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDropdownField(
            label: 'Food Allergies',
            value: null,
            options: options,
            onChanged: (_) {},
            hintText: 'Select Allergies',
            showSearchBar: true,
            multiSelect: true,
            selectedValues: _selectedMultiValues,
            onChangedMulti: (values) {
              setState(() {
                // Allow explicit 'No allergies' as a value but not with others
                if (values.contains('No allergies')) {
                  _selectedMultiValues = ['No allergies'];
                } else {
                  _selectedMultiValues = values;
                }
              });
            },
          ),
          if (_selectedMultiValues.isNotEmpty) ...[
            const SizedBox(height: 16),
            AppChipGroup(
              values: _selectedMultiValues,
              onChanged: (values) {
                setState(() {
                  // Respect 'No allergies' exclusivity
                  if (values.contains('No allergies') && values.length > 1) {
                    _selectedMultiValues = ['No allergies'];
                  } else {
                    _selectedMultiValues = values;
                  }
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthGoalsEdit() {
    final options = const [
      'Avoid diabetes',
      'Lower blood pressure',
      'Lower cholesterol',
      'Lower blood glucose (Sugar)',
      'Lose weight',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCheckboxGroup(
            label: 'Diet-related Health Goals',
            selectedValues: _selectedMultiValues,
            options: options,
            onChanged: (values) {
              setState(() {
                _selectedMultiValues = values;
              });
            },
          ),
          if (_selectedMultiValues.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Selected Goals:',
              style: AppTypography.bg_14_m,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedMultiValues
                  .map((goal) => Chip(
                        label: Text(goal),
                        backgroundColor: const Color(0xFFFFEFE7),
                        labelStyle: const TextStyle(
                          color: Color(0xFFFF6A00),
                          fontSize: 12,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

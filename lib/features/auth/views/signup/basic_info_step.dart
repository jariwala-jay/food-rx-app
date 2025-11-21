import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_app/features/auth/providers/signup_provider.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';

class BasicInfoStep extends StatefulWidget {
  final VoidCallback onNext;

  const BasicInfoStep({
    super.key,
    required this.onNext,
  });

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _error;
  File? _profilePhoto;
  String? _profilePhotoPath;
  final FocusNode _emailFocusNode = FocusNode();
  String? _emailExistsError;

  @override
  void initState() {
    super.initState();
    final signupData = context.read<SignupProvider>().data;
    _nameController.text = signupData.name ?? '';
    _emailController.text = signupData.email ?? '';
    _passwordController.text = signupData.password ?? '';
    _confirmPasswordController.text = signupData.password ?? '';

    // Clear email error when user types
    _emailController.addListener(() {
      if (_emailExistsError != null) {
        setState(() {
          _emailExistsError = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profilePhoto = File(pickedFile.path);
          _profilePhotoPath = pickedFile.path;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _handleNext() async {
    // Clear email error before validation
    setState(() {
      _emailExistsError = null;
    });

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        // Additional required field validations
        if (_nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter your name'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        if (_emailController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter your email'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Check if email already exists in database
        // Clear any previous email error first
        setState(() {
          _emailExistsError = null;
        });

        final authController = context.read<AuthController>();
        final emailExists =
            await authController.checkEmailExists(_emailController.text.trim());
        if (emailExists) {
          setState(() {
            _isLoading = false;
            _emailExistsError =
                'This email is already registered. Please use a different email or try logging in.';
          });
          // Focus on email field and show error
          _emailFocusNode.requestFocus();
          // Trigger form validation to show error
          _formKey.currentState?.validate();
          return;
        }

        if (_passwordController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter your password'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        if (_confirmPasswordController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please confirm your password'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Store the data in SignupProvider instead of registering
        context.read<SignupProvider>().updateBasicInfo(
              name: _nameController.text,
              email: _emailController.text,
              password: _passwordController.text,
              profilePhoto: _profilePhoto,
            );

        widget.onNext();
      } catch (e) {
        setState(() {
          _error = 'An error occurred: $e';
        });
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F8),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE7E9EC),
                              width: 1,
                            ),
                            image: _profilePhotoPath != null
                                ? DecorationImage(
                                    image: FileImage(File(_profilePhotoPath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _profilePhotoPath == null
                              ? const Center(
                                  child: Icon(
                                    Icons.person_outline,
                                    size: 48,
                                    color: Color(0xFF90909A),
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _pickImage,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6A00),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                          label: 'Name',
                          hintText: 'Enter your name',
                          controller: _nameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppFormField(
                          label: 'Email',
                          hintText: 'Enter your email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          focusNode: _emailFocusNode,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Please enter a valid email';
                            }
                            if (_emailExistsError != null) {
                              return _emailExistsError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AppFormField(
                          label: 'Password',
                          hintText: 'Enter your password',
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            if (!value.contains(RegExp(r'[A-Z]'))) {
                              return 'Password must contain at least one uppercase letter';
                            }
                            if (!value.contains(RegExp(r'[a-z]'))) {
                              return 'Password must contain at least one lowercase letter';
                            }
                            if (!value.contains(RegExp(r'[0-9]'))) {
                              return 'Password must contain at least one number';
                            }
                            if (!value
                                .contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                              return 'Password must contain at least one special character';
                            }
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF90909A),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _passwordController,
                          builder: (context, value, child) {
                            return _buildPasswordRequirements();
                          },
                        ),
                        const SizedBox(height: 16),
                        AppFormField(
                          label: 'Confirm Password',
                          hintText: 'Re-Enter your password',
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF90909A),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
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
            child: SizedBox(
              width: double.infinity,
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
        ),
      ],
    );
  }

  bool _hasMinLength(String password) => password.length >= 8;
  bool _hasUppercase(String password) => password.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String password) => password.contains(RegExp(r'[a-z]'));
  bool _hasNumber(String password) => password.contains(RegExp(r'[0-9]'));
  bool _hasSpecialChar(String password) =>
      password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  Widget _buildPasswordRequirements() {
    final password = _passwordController.text;
    final requirements = [
      {
        'text': 'At least 8 characters',
        'met': _hasMinLength(password),
      },
      {
        'text': 'One uppercase letter',
        'met': _hasUppercase(password),
      },
      {
        'text': 'One lowercase letter',
        'met': _hasLowercase(password),
      },
      {
        'text': 'One number',
        'met': _hasNumber(password),
      },
      {
        'text': 'One special character',
        'met': _hasSpecialChar(password),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password must contain:',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'BricolageGrotesque',
              color: const Color(0xFF8E8E93),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...requirements.map((req) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      req['met'] as bool
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 16,
                      color: req['met'] as bool
                          ? const Color(0xFF34C759)
                          : const Color(0xFFC7C7CC),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        req['text'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'BricolageGrotesque',
                          color: req['met'] as bool
                              ? const Color(0xFF34C759)
                              : const Color(0xFF8E8E93),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

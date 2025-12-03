import 'package:flutter/material.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:provider/provider.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? token;

  const ResetPasswordPage({super.key, this.token});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isValidatingToken = true;
  bool _tokenValid = false;
  bool _passwordReset = false;
  String? _errorMessage;
  
  // Password requirement checkers
  bool _hasMinLength(String password) => password.length >= 8;
  bool _hasUppercase(String password) => password.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String password) => password.contains(RegExp(r'[a-z]'));
  bool _hasNumber(String password) => password.contains(RegExp(r'[0-9]'));
  bool _hasSpecialChar(String password) =>
      password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  @override
  void initState() {
    super.initState();
    // Delay validation to avoid build phase issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _validateToken();
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _validateToken() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() {
        _isValidatingToken = false;
        _tokenValid = false;
        _errorMessage = 'Invalid reset link. Please request a new password reset.';
      });
      return;
    }

    try {
      final authController = context.read<AuthController>();
      final isValid = await authController.validatePasswordResetToken(widget.token!);

      if (!mounted) return;
      setState(() {
        _isValidatingToken = false;
        _tokenValid = isValid;
        if (!isValid) {
          _errorMessage = authController.error ?? 'This reset link is invalid or has expired. Please request a new password reset.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidatingToken = false;
        _tokenValid = false;
        _errorMessage = 'An error occurred while validating the reset link: $e';
      });
    }
  }

  Future<void> _handleResetPassword() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authController = context.read<AuthController>();
      final success = await authController.resetPassword(
        widget.token!,
        _passwordController.text,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (success) {
          _passwordReset = true;
        } else {
          _errorMessage = authController.error ?? 'Failed to reset password';
        }
      });

      if (!success && _errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation to invalid deep link state
        // Navigate to login instead
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
        return false;
      },
      child: GestureDetector(
        // Dismiss keyboard when tapping outside
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F7F8),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
            onPressed: () {
              // Navigate to login instead of just popping
              // This prevents navigation stack issues
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
          ),
        ),
        body: SingleChildScrollView(
          // Enable scrolling when keyboard appears
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reset Password', style: AppTypography.bg_24_b),
                  const SizedBox(height: 8),
                  if (_isValidatingToken) ...[
                    const SizedBox(height: 40),
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Validating reset link...',
                        style: AppTypography.bg_14_r,
                      ),
                    ),
                  ] else if (!_tokenValid) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Invalid reset link',
                      style: AppTypography.bg_14_r.copyWith(
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
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
                        onPressed: () => Navigator.of(context).pushReplacementNamed('/forgot-password'),
                        child: const Text('Request New Reset Link',
                            style: AppTypography.bg_16_sb),
                      ),
                    ),
                  ] else if (_passwordReset) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Your password has been successfully reset. You can now login with your new password.',
                      style: AppTypography.bg_14_r
                          .copyWith(color: const Color(0xFF90909A)),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF4CAF50),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Password Reset!',
                            style: AppTypography.bg_18_b,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your password has been successfully reset. You can now login with your new password.',
                            style: AppTypography.bg_14_r.copyWith(
                              color: const Color(0xFF90909A),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
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
                        onPressed: () {
                          // Clear navigation stack and go to login
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                            (route) => false,
                          );
                        },
                        child: const Text('Go to Login',
                            style: AppTypography.bg_16_sb),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Enter your new password below.',
                      style: AppTypography.bg_14_r
                          .copyWith(color: const Color(0xFF90909A)),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppFormField(
                            label: 'New Password',
                            hintText: 'Enter your new password',
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) {
                              _passwordFocusNode.unfocus();
                              FocusScope.of(context)
                                  .requestFocus(_confirmPasswordFocusNode);
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your new password';
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
                              if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
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
                          const SizedBox(height: 20),
                          AppFormField(
                            label: 'Confirm Password',
                            hintText: 'Confirm your new password',
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocusNode,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleResetPassword(),
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
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
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
                        onPressed: _isLoading ? null : _handleResetPassword,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Reset Password',
                                style: AppTypography.bg_16_sb),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

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


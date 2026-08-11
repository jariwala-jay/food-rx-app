import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/auth/biometric_sign_in_labels.dart';
import 'package:flutter_app/core/utils/user_facing_errors.dart';
import 'package:flutter_app/core/widgets/google_sign_in_button.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/widgets/app_outlined_icon_button.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _hasSavedLogin = false;
  BiometricSignInLabels? _biometricLabels;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authController = context.read<AuthController>();
      final saved = await authController.hasSavedLogin();
      BiometricSignInLabels? labels;
      if (saved) {
        labels = await authController.getBiometricSignInLabels();
      }
      if (!mounted) return;
      setState(() {
        _hasSavedLogin = saved;
        _biometricLabels = labels;
        if (authController.error != null) {
          _errorMessage = authController.error;
        }
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    try {
      final authController = context.read<AuthController>();
      final success = await authController.loginWithGoogle();
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (success) {
        // LoginPage is pushed on top of Consumer<AuthController>'s home
        // widget, so rebuilding home alone won't pop this route.
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      if (authController.error != null) {
        setState(() => _errorMessage = authController.error);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(authController.error!),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGoogleLoading = false;
        _errorMessage = userFacingErrorMessage(e);
      });
    }
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authController = context.read<AuthController>();
      final success = await authController.login(email, password);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!success) {
          _errorMessage = authController.error ?? 'Invalid credentials';
        }
      });

      if (success) {
        TextInput.finishAutofillContext(shouldSave: true);
        _emailController.clear();
        _passwordController.clear();
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          }
        }
      } else {
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
        _errorMessage = userFacingErrorMessage(e);
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

  Future<void> _handleBiometricLogin() async {
    FocusScope.of(context).unfocus();
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authController = context.read<AuthController>();
      final success = await authController.loginWithSavedCredentials();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!success) {
          _errorMessage =
              authController.error ?? 'Could not sign in with saved login';
        }
      });

      if (success && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
        }
      } else if (mounted && _errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = userFacingErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F7F8),
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const Text(
                          'Welcome to MyFoodRx!',
                          style: AppTypography.bg_24_b,
                        ),
                        Text(
                          'Login to your account to continue.',
                          style: AppTypography.bg_14_r
                              .copyWith(color: const Color(0xFF5F5F6E)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'If you don\'t have an account, click the Create Now button at the bottom of the screen to make your account and get started',
                          style: AppTypography.bg_14_r
                              .copyWith(color: const Color(0xFF5F5F6E)),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 16),
                          margin: const EdgeInsets.only(top: 80, bottom: 20),
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
                                label: 'Email',
                                hintText: 'Enter your email',
                                controller: _emailController,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                focusNode: _emailFocusNode,
                                keyboardType: TextInputType.emailAddress,
                                enableSuggestions: false,
                                autocorrect: false,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) {
                                  _emailFocusNode.unfocus();
                                  FocusScope.of(context)
                                      .requestFocus(_passwordFocusNode);
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              AppFormField(
                                label: 'Password',
                                hintText: 'Enter your password',
                                controller: _passwordController,
                                autofillHints: const [AutofillHints.password],
                                focusNode: _passwordFocusNode,
                                obscureText: _obscurePassword,
                                enableSuggestions: false,
                                autocorrect: false,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleLogin(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
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
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    Navigator.pushNamed(
                                        context, '/forgot-password');
                                  },
                                  child: const Padding(
                                    // GestureDetector only hit-tests its child's painted
                                    // bounds by default — at 12px text that's a sliver too
                                    // small to tap reliably. Pad the tap target out without
                                    // changing how the text looks.
                                    padding: EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 8),
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: Color(0xFF545454),
                                        fontSize: 12,
                                        fontFamily: 'Bricolage Grotesque',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
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
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        if (_hasSavedLogin && _biometricLabels != null) ...[
                          AppOutlinedIconButton(
                            onPressed:
                                _isLoading ? null : _handleBiometricLogin,
                            icon: _biometricLabels!.continueIcon,
                            label: _biometricLabels!.continueButton,
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6A00),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 48),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Submit',
                                    style: AppTypography.bg_16_sb),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: Color(0xFF90909A),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GoogleSignInButton(
                          isLoading: _isGoogleLoading,
                          onPressed:
                              _isLoading ? null : _handleGoogleSignIn,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              Navigator.pushNamed(context, '/signup');
                            },
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "Don't have an account? ",
                                      style: TextStyle(
                                        color: Color(0xFF545454),
                                        fontSize: 16,
                                        fontFamily: 'Bricolage Grotesque',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Create Now',
                                      style: TextStyle(
                                        color: Color(0xFFFF6A00),
                                        fontSize: 16,
                                        fontFamily: 'Bricolage Grotesque',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}

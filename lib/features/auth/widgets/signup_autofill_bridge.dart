import 'package:flutter/material.dart';

class SignupAutofillBridge extends StatelessWidget {
  const SignupAutofillBridge({
    super.key,
    required this.emailController,
    required this.passwordController,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      child: SizedBox(
        width: 1,
        height: 1,
        child: Column(
          children: [
            TextField(
              controller: emailController,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: true,
            ),
          ],
        ),
      ),
    );
  }
}

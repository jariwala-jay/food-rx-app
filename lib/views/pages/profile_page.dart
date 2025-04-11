import 'package:flutter/material.dart';
import 'package:flutter_app/utils/typography.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InputFieldsWidget("Name", "Enter your name"),
            SizedBox(height: 20),
            InputFieldsWidget("Email", "Enter your email"),
            SizedBox(height: 20),
            InputFieldsWidget("Password", "Enter your password"),
            SizedBox(height: 20),
            InputFieldsWidget("Confirm Password", "Re-enter your password"),
          ],
        ),
      ),
    );
  }
}

class InputFieldsWidget extends StatelessWidget {
  const InputFieldsWidget(this.label, this.hintText, {super.key});
  final String label;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bg_16_m.copyWith(color: Colors.black)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: ShapeDecoration(
            color: const Color(0xFFF7F7F8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: TextField(
            style:
                AppTypography.bg_14_r.copyWith(color: const Color(0xFF2C2C2C)),
            decoration: InputDecoration(
              border: InputBorder.none,
              fillColor: Colors.black,
              hintText: hintText,
              hintStyle: AppTypography.bg_14_r.copyWith(
                color: const Color(0xFF90909A),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

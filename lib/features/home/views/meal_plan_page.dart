import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/models/user_model.dart';

class MealPlanPage extends StatelessWidget {
  const MealPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Meal Plan',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<AuthController>(
        builder: (context, authController, child) {
          final user = authController.currentUser;

          if (user == null) {
            return const Center(
              child: Text('Please log in to view your meal plan'),
            );
          }

          // Navigate directly to diet plan viewer
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/diet-plan-viewer',
                arguments: {
                  'myPlanType': user.myPlanType ?? user.dietType ?? 'MyPlate',
                  'displayName': _getPlanDisplayName(user),
                  'showGlycemicIndex': user.showGlycemicIndex ?? false,
                });
          });

          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
            ),
          );
        },
      ),
    );
  }

  String _getPlanDisplayName(UserModel user) {
    final myPlan = user.myPlanType ?? user.dietType ?? 'MyPlate';
    switch (myPlan) {
      case 'DiabetesPlate':
        return 'Diabetes Plate (ADA)';
      case 'DASH':
        return 'DASH Diet';
      case 'MyPlate':
        return 'MyPlate Nutrition';
      default:
        return myPlan;
    }
  }
}

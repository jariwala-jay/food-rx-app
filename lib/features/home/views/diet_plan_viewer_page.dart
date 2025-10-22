import 'package:flutter/material.dart';
import 'package:flutter_app/features/home/widgets/diet_plan_viewer.dart';

class DietPlanViewerPage extends StatelessWidget {
  final String myPlanType;
  final String displayName;

  const DietPlanViewerPage({
    Key? key,
    required this.myPlanType,
    required this.displayName,
  }) : super(key: key);

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
        title: Text(
          '$displayName Details',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: DietPlanViewer(myPlanType: myPlanType),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_app/features/home/widgets/diet_plan_viewer.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';

class DietPlanViewerPage extends StatelessWidget {
  final String myPlanType;
  final String displayName;
  final bool showGlycemicIndex;

  const DietPlanViewerPage({
    Key? key,
    required this.myPlanType,
    required this.displayName,
    this.showGlycemicIndex = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Consumer<ForcedTourProvider>(
          builder: (context, tourProvider, child) {
            return IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: tourProvider.isTourActive
                  ? null
                  : () => Navigator.of(context).pop(),
            );
          },
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
      body: DietPlanViewer(
        myPlanType: myPlanType,
        showGlycemicIndex: showGlycemicIndex,
      ),
    );
  }
}

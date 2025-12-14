import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';

class TourCompletionDialog extends StatelessWidget {
  const TourCompletionDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Clamp text scale factor to prevent excessive scaling
    final textScaleFactor =
        MediaQuery.textScaleFactorOf(context).clamp(0.8, 1.2);
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogHeight = screenHeight * 0.75; // Max 75% of screen height

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxDialogHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fixed header: Logo and title
              SizedBox(
                width: 100,
                height: 100,
                child: Image.asset(
                  'assets/icons/myfoodrx_logo.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),

              SizedBox(height: 24 * textScaleFactor),

              Text(
                'Congratulations!',
                style: TextStyle(
                  fontSize: 24 * textScaleFactor,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 20 * textScaleFactor),

              // Scrollable middle section: Message box
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(16 * textScaleFactor),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEFE7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF6A00).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'You\'re all set!',
                          style: TextStyle(
                            fontSize: 18 * textScaleFactor,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8 * textScaleFactor),
                        Text(
                          'Now you know how to use the app! You can move forward and track your nutrition, manage your pantry, generate recipes, and use all the features on your own.',
                          style: TextStyle(
                            fontSize: 14 * textScaleFactor,
                            color: const Color(0xFF666666),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24 * textScaleFactor),

              // Fixed footer: Button (always visible)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final tourProvider =
                        Provider.of<ForcedTourProvider>(context, listen: false);

                    // Clear tour items before completing tour
                    try {
                      final pantryController =
                          Provider.of<PantryController>(context, listen: false);
                      await pantryController.clearTourItems();
                    } catch (e) {
                      print('Error clearing tour items: $e');
                    }

                    await tourProvider.completeTour();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: 16 * textScaleFactor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Got it!',
                    style: TextStyle(
                      fontSize: 16 * textScaleFactor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

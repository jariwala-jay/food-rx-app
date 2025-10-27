import 'package:flutter/material.dart';
import 'package:flutter_app/features/home/views/home_page.dart';
import 'package:flutter_app/features/education/views/education_page.dart';
import 'package:flutter_app/features/navigation/widgets/custom_nav_bar.dart';
import 'package:flutter_app/features/pantry/views/pantry_page.dart';
import 'package:flutter_app/features/recipes/views/recipe_page.dart';
import 'package:flutter_app/features/navigation/widgets/add_action_sheet.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isAddActive = false;
  final List<Widget> _pages = [
    const HomePage(),
    const PantryPage(),
    const RecipePage(),
    const EducationPage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // Start tour for first-time users using v5.0.1 API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tourProvider =
          Provider.of<ForcedTourProvider>(context, listen: false);

      // Start tour if needed
      if (tourProvider.tourService.shouldShowTour() &&
          !tourProvider.isTourActive) {
        tourProvider.startTour();

        // Start the showcase sequence using the correct v5.0.1 API
        // Start with just the first step
        ShowcaseView.get().startShowCase([TourKeys.trackersKey]);
      }
    });
  }

  void _handleAddTap() async {
    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);

    setState(() => _isAddActive = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddActionSheet(),
    );
    setState(() => _isAddActive = false);

    // Handle tour progression if on add button step
    if (tourProvider.isOnStep(TourStep.addButton)) {
      tourProvider.completeCurrentStep();
    }

    // Check if we should show Pantry tab (either on recipes step or just completed addButton)
    final currentStep = tourProvider.currentStep;
    if (currentStep == TourStep.recipes ||
        currentStep == TourStep.pantryItems) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            ShowcaseView.get().startShowCase([TourKeys.pantryTabKey]);
            print(
                '🎯 MainScreen: Triggered Pantry tab showcase - step: $currentStep');
          } catch (e) {}
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ForcedTourProvider>(
      builder: (context, tourProvider, child) {
        Widget scaffold = WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            body: Stack(
              children: [
                IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
                // DEBUG: Tour control buttons
                if (dotenv.env['SHOW_TOUR_DEBUG_BUTTON'] == 'true')
                  Positioned(
                    top: 50,
                    right: 16,
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            tourProvider.startTour();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          child: const Text('Start Tour',
                              style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(height: 4),
                        ElevatedButton(
                          onPressed: () async {
                            await tourProvider.resetTour();
                            if (context.mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                tourProvider.startTour();
                                ShowcaseView.get()
                                    .startShowCase([TourKeys.trackersKey]);
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          child: const Text('Reset Tour',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: CustomNavBar(
                  currentIndex: _currentIndex,
                  onHomeTap: () => setState(() => _currentIndex = 0),
                  onPantryTap: () => setState(() => _currentIndex = 1),
                  onRecipeTap: () => setState(() => _currentIndex = 2),
                  onEducationTap: () => setState(() => _currentIndex = 3),
                  onChatTap: () {
                    Navigator.pushNamed(context, '/chatbot');
                  },
                  isAddActive: _isAddActive,
                  onAddTap: _handleAddTap,
                ),
              ),
            ),
          ),
        );

        // Note: Tour showcases are handled by individual pages
        // HomePage handles: trackers, dailyTips, myPlan, addButton
        // PantryPage handles: pantryItems
        // RecipePage handles: recipes
        // EducationPage handles: education

        return scaffold;
      },
    );
  }
}

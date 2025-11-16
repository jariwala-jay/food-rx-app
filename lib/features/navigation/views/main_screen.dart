import 'package:flutter/material.dart';
import 'package:flutter_app/features/home/views/home_page.dart';
import 'package:flutter_app/features/education/views/education_page.dart';
import 'package:flutter_app/features/navigation/widgets/custom_nav_bar.dart';
import 'package:flutter_app/features/pantry/views/pantry_page.dart';
import 'package:flutter_app/features/recipes/views/recipe_page.dart';
import 'package:flutter_app/features/navigation/widgets/add_action_sheet.dart';
import 'package:flutter_app/features/home/widgets/tour_welcome_dialog.dart';
import 'package:flutter_app/features/home/widgets/tour_completion_dialog.dart';
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
  bool _isDisposed = false;
  bool _wasTourActive = false;
  bool _hasShownCompletionDialog = false;
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

    // Show welcome dialog and start tour for first-time users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) return;
      final tourProvider =
          Provider.of<ForcedTourProvider>(context, listen: false);

      // Show welcome dialog if tour should be shown
      if (tourProvider.tourService.shouldShowTour() &&
          !tourProvider.isTourActive &&
          !tourProvider.hasTriggeredInitialShowcase) {
        // Show welcome dialog first
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _isDisposed) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const TourWelcomeDialog(),
          ).then((_) {
            // After dialog is dismissed, start the tour
            if (!mounted || _isDisposed) return;
            _startTour();
          });
        });
      }
    });
  }

  void _startTour() {
    if (!mounted || _isDisposed) return;
    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);

    // Start tour if needed
    if (tourProvider.tourService.shouldShowTour() &&
        !tourProvider.isTourActive &&
        !tourProvider.hasTriggeredInitialShowcase) {
      tourProvider.startTour();

      // Only start showcase if we're on the trackers step and haven't triggered yet
      // Start the showcase sequence using the correct v5.0.1 API
      if (mounted &&
          !_isDisposed &&
          tourProvider.isOnStep(TourStep.trackers) &&
          !tourProvider.hasTriggeredInitialShowcase) {
        // Mark as triggered immediately to prevent duplicate calls
        tourProvider.markInitialShowcaseTriggered();

        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _isDisposed) return;
          try {
            final tp = Provider.of<ForcedTourProvider>(context, listen: false);
            // Double-check we're still on trackers step and have triggered flag set
            if (tp.isOnStep(TourStep.trackers) &&
                tp.hasTriggeredInitialShowcase) {
              // Dismiss any existing showcase first to prevent duplicates
              ShowcaseView.get().dismiss();
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!mounted || _isDisposed) return;
                final tp2 =
                    Provider.of<ForcedTourProvider>(context, listen: false);
                // Final check before starting - ensure we're still on trackers step
                if (tp2.isOnStep(TourStep.trackers)) {
                  try {
                    ShowcaseView.get().startShowCase([TourKeys.trackersKey]);
                    print(
                        '🎯 MainScreen: Started trackers showcase (single trigger)');
                  } catch (e) {
                    print('🎯 MainScreen: Error starting showcase: $e');
                    // Reset flag on error so it can be retried
                    tp2.startTour(); // This will reset the flag
                  }
                }
              });
            } else {
              // If step changed or flag wasn't set, reset so it can be retried
              if (!tp.isOnStep(TourStep.trackers)) {
                tp.startTour(); // Reset the flag
              }
            }
          } catch (e) {
            print('🎯 MainScreen: Error starting initial showcase: $e');
            // Reset flag on error
            tourProvider.startTour(); // This will reset the flag
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _handleAddTap() async {
    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);

    if (!mounted || _isDisposed) return;
    setState(() => _isAddActive = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddActionSheet(),
    );

    // Only update state if still mounted
    if (mounted && !_isDisposed) {
      setState(() => _isAddActive = false);
    }

    // Handle tour progression - only if we're past the item adding steps
    // The addButton step is now completed when user clicks "Add FoodRx Items"
    // and we move through selectCategory -> selectItem -> setQuantityUnit -> pantryItems
    if (!mounted || _isDisposed) return;

    // Only handle pantryItems step here (after items are added)
    final currentStep = tourProvider.currentStep;
    if (currentStep == TourStep.pantryItems) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) return;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _isDisposed) return;
          try {
            final tp = Provider.of<ForcedTourProvider>(context, listen: false);
            if (tp.isOnStep(TourStep.pantryItems)) {
              ShowcaseView.get().dismiss();
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!mounted || _isDisposed) return;
                final tp2 =
                    Provider.of<ForcedTourProvider>(context, listen: false);
                if (tp2.isOnStep(TourStep.pantryItems)) {
                  ShowcaseView.get().startShowCase([TourKeys.pantryTabKey]);
                  print(
                      '🎯 MainScreen: Triggered Pantry tab showcase after adding items');
                }
              });
            }
          } catch (e) {
            print('🎯 MainScreen: Error triggering pantry tab showcase: $e');
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ForcedTourProvider>(
      builder: (context, tourProvider, child) {
        // Listen for tour completion to show completion dialog (backup method)
        if (_wasTourActive &&
            !tourProvider.isTourActive &&
            tourProvider.tourCompleted &&
            !_hasShownCompletionDialog) {
          // Tour just completed, show completion dialog
          _hasShownCompletionDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDisposed) {
              Future.delayed(const Duration(milliseconds: 1200), () {
                if (mounted && !_isDisposed && context.mounted) {
                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => const TourCompletionDialog(),
                    );
                  } catch (e) {
                    debugPrint(
                        'MainScreen: Error showing completion dialog: $e');
                  }
                }
              });
            }
          });
        }
        _wasTourActive = tourProvider.isTourActive;
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
                            if (mounted && !_isDisposed && context.mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted || _isDisposed) return;
                                tourProvider.startTour();
                                if (mounted && !_isDisposed) {
                                  ShowcaseView.get()
                                      .startShowCase([TourKeys.trackersKey]);
                                }
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
                  onHomeTap: () {
                    if (mounted && !_isDisposed) {
                      setState(() => _currentIndex = 0);
                    }
                  },
                  onPantryTap: () {
                    if (mounted && !_isDisposed) {
                      setState(() => _currentIndex = 1);
                    }
                  },
                  onRecipeTap: () {
                    if (mounted && !_isDisposed) {
                      setState(() => _currentIndex = 2);
                    }
                  },
                  onEducationTap: () {
                    if (mounted && !_isDisposed) {
                      setState(() => _currentIndex = 3);
                    }
                  },
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

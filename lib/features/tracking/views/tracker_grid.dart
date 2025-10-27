import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/tracker_provider.dart';
import '../models/tracker_goal.dart';
import '../widgets/tracker_card.dart';
import '../widgets/pantry_tracker_logging_modal.dart';
import '../widgets/manual_tracker_logging_modal.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart' as showcaseview;

class TrackerGrid extends StatefulWidget {
  final String userId;
  final String dietType;

  const TrackerGrid({
    Key? key,
    required this.userId,
    required this.dietType,
  }) : super(key: key);

  @override
  State<TrackerGrid> createState() => _TrackerGridState();
}

class _TrackerGridState extends State<TrackerGrid>
    with SingleTickerProviderStateMixin {
  Timer? _loadingTimer;
  bool _showLoadingTimeout = false;
  bool _hasInitialized = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrackers();
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _loadTrackers() {
    if (_hasInitialized) return;

    _hasInitialized = true;
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    provider.loadUserTrackers(widget.userId, widget.dietType);

    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _showLoadingTimeout = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, trackerProvider, child) {
        if (!trackerProvider.isLoading) {
          _loadingTimer?.cancel();
          _animationController.stop();
        }

        if (trackerProvider.isLoading) {
          if (_showLoadingTimeout) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'This is taking longer than expected...',
                    style: TextStyle(color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'We\'re connecting to the database. This might be slow if you have a poor connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showLoadingTimeout = false;
                          });
                          _loadTrackers();
                        },
                        child: const Text('Retry'),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          // Show a skeleton loading state that maintains layout
          return _buildSkeletonLoading();
        }

        if (trackerProvider.error != null) {
          String errorMessage = trackerProvider.error ?? 'Unknown error';
          String friendlyMessage =
              'An error occurred while loading your trackers.';

          if (errorMessage.contains('timed out') ||
              errorMessage.contains('TimeoutException')) {
            friendlyMessage =
                'Connection to the database timed out. Please check your internet connection and try again.';
          }

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Nutrition Tracker Error',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    friendlyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadTrackers,
                  child: const Text('Retry Loading'),
                ),
              ],
            ),
          );
        }

        final dailyTrackers = trackerProvider.dailyTrackers;
        final weeklyTrackers = trackerProvider.weeklyTrackers;

        if (dailyTrackers.isEmpty && weeklyTrackers.isEmpty) {
          // Show skeleton loading instead of manual initialization button
          return _buildSkeletonLoading();
        }

        print(
            '🎯 TrackerGrid: Showing main tracker display with ${dailyTrackers.length} daily trackers');

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Meal Plan Goals',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      return showcaseview.Showcase(
                        key: TourKeys.myPlanButtonKey,
                        title: 'View Your Diet Plan',
                        description:
                            'Tap here to see your personalized meal plan with detailed nutrition guidelines.',
                        targetShapeBorder: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        tooltipBackgroundColor: Colors.white,
                        textColor: Colors.black,
                        overlayColor: Colors.black54,
                        overlayOpacity: 0.8,
                        onTargetClick: () {
                          print(
                              '🎯 TrackerGrid: User tapped on My Plan showcase - navigating');
                          // Navigate to meal plan page - don't complete step yet
                          Navigator.pushNamed(context, '/meal-plan');
                          // Step will be completed when user clicks "Continue Tour" on diet plan page
                        },
                        onToolTipClick: () {
                          print(
                              '🎯 TrackerGrid: User clicked on My Plan tooltip - navigating');
                          // Navigate to meal plan page
                          Navigator.pushNamed(context, '/meal-plan');
                        },
                        disposeOnTap: true,
                        child: ElevatedButton(
                          onPressed: () {
                            print(
                                '🎯 TrackerGrid: User clicked on My Plan button');
                            // Navigate to meal plan page - don't complete step yet
                            Navigator.pushNamed(context, '/meal-plan');
                            // Step will be completed when user clicks "Continue Tour" on diet plan page
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFFF6B35), // Orange color
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'My Plan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 152 / 68,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: dailyTrackers.length,
                itemBuilder: (context, index) {
                  final tracker = dailyTrackers[index];
                  return _buildTrackerCard(context, tracker);
                },
              ),
              if (weeklyTrackers.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Weekly Goals',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 152 / 68,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: weeklyTrackers.length,
                  itemBuilder: (context, index) {
                    final tracker = weeklyTrackers[index];
                    return _buildTrackerCard(context, tracker);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackerCard(BuildContext context, TrackerGoal tracker) {
    return Selector<TrackerProvider, TrackerGoal?>(
      selector: (context, provider) => provider.findTrackerById(tracker.id),
      builder: (context, currentTracker, child) {
        final displayTracker = currentTracker ?? tracker;
        return TrackerCard(
          key: ValueKey(displayTracker.id),
          tracker: displayTracker,
          onTap: () => _showEditDialog(context, displayTracker),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, TrackerGoal tracker) {
    // Check if this category should use manual entry or pantry selection
    if (isManualEntryCategory(tracker.category)) {
      // Show manual numeric input modal
      showDialog(
        context: context,
        builder: (context) => ManualTrackerLoggingModal(
          tracker: tracker,
          onLog: (newValue) async {
            try {
              await Provider.of<TrackerProvider>(context, listen: false)
                  .updateTrackerValueOptimized(
                      tracker.id, tracker.currentValue + newValue);
              return true;
            } catch (e) {
              return Future.error(e);
            }
          },
        ),
      );
    } else {
      // Show pantry-based selection modal
      showDialog(
        context: context,
        builder: (context) => PantryTrackerLoggingModal(
          tracker: tracker,
          onLog: (newValue) async {
            try {
              await Provider.of<TrackerProvider>(context, listen: false)
                  .updateTrackerValueOptimized(
                      tracker.id, tracker.currentValue + newValue);
              return true;
            } catch (e) {
              return Future.error(e);
            }
          },
        ),
      );
    }
  }

  Widget _buildSkeletonLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Meal Plan Goals',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Builder(
                builder: (context) {
                  print(
                      '🎯 TrackerGrid: Building My Plan showcase widget (skeleton)');
                  return showcaseview.Showcase(
                    key: TourKeys.myPlanButtonKey,
                    title: 'View Your Diet Plan',
                    description:
                        'Tap here to see your personalized meal plan with detailed nutrition guidelines.',
                    targetShapeBorder: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    tooltipBackgroundColor: Colors.white,
                    textColor: Colors.black,
                    overlayColor: Colors.black54,
                    overlayOpacity: 0.8,
                    onTargetClick: () {
                      print(
                          '🎯 TrackerGrid: User tapped on My Plan showcase (skeleton) - navigating');
                      // Navigate to meal plan page - don't complete step yet
                      Navigator.pushNamed(context, '/meal-plan');
                      // Step will be completed when user clicks "Continue Tour" on diet plan page
                    },
                    onToolTipClick: () {
                      print(
                          '🎯 TrackerGrid: User clicked on My Plan tooltip (skeleton) - navigating');
                      Navigator.pushNamed(context, '/meal-plan');
                    },
                    disposeOnTap: false,
                    child: ElevatedButton(
                      onPressed: () {
                        print(
                            '🎯 TrackerGrid: User clicked on My Plan button (skeleton)');
                        // Navigate to meal plan page - don't complete step yet
                        Navigator.pushNamed(context, '/meal-plan');
                        // Step will be completed when user clicks "Continue Tour" on diet plan page
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFFF6B35), // Orange color
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'My Plan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 152 / 68,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 8, // Show 4 daily skeleton cards
            itemBuilder: (context, index) {
              return _buildSkeletonCard();
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Weekly Goals',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 152 / 68,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 2, // Show 4 weekly skeleton cards
            itemBuilder: (context, index) {
              return _buildSkeletonCard();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 152,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  // Left - Skeleton circle
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Right - Skeleton text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 14,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 12,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

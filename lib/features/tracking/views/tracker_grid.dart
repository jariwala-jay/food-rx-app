import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/tracker_provider.dart';
import '../models/tracker_goal.dart';
import '../widgets/tracker_card.dart';
import '../widgets/tracker_edit_dialog.dart';

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

class _TrackerGridState extends State<TrackerGrid> {
  Timer? _loadingTimer;
  bool _showLoadingTimeout = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrackers();
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
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

  void _initializeTrackers() {
    final provider = Provider.of<TrackerProvider>(context, listen: false);
    provider.initializeUserTrackers(widget.userId, widget.dietType);

    setState(() {
      _showLoadingTimeout = false;
    });

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
          return const Center(child: CircularProgressIndicator());
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _loadTrackers,
                      child: const Text('Retry Loading'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _initializeTrackers,
                      child: const Text('Initialize New'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final dailyTrackers = trackerProvider.dailyTrackers;
        final weeklyTrackers = trackerProvider.weeklyTrackers;

        if (dailyTrackers.isEmpty && weeklyTrackers.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.track_changes, color: Colors.grey, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'No trackers found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Let\'s set up your nutrition trackers',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeTrackers,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Initialize Trackers'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today\'s Top Goals',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
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
      selector: (_, provider) => provider.findTrackerById(tracker.id),
      builder: (context, updatedTracker, _) {
        final currentTracker = updatedTracker ?? tracker;
        return TrackerCard(
          key: ValueKey(currentTracker.id),
          tracker: currentTracker,
          onTap: () => _showEditDialog(context, currentTracker),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, TrackerGoal tracker) {
    showDialog(
      context: context,
      builder: (context) => TrackerEditDialog(
        tracker: tracker,
        onUpdate: (newValue) async {
          try {
            await Provider.of<TrackerProvider>(context, listen: false)
                .updateTrackerValue(tracker.id, newValue);
            return true;
          } catch (e) {
            return Future.error(e);
          }
        },
      ),
    );
  }
}

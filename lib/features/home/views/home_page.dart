// lib/features/home/views/home_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

// Local Imports
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/home/providers/tip_provider.dart';
import 'package:flutter_app/features/home/models/tip.dart';
import 'package:flutter_app/core/services/image_cache_service.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/features/tracking/views/tracker_grid.dart';
import 'package:flutter_app/features/tracking/controller/tracker_provider.dart';
import 'package:flutter_app/features/notifications/views/notification_testing_page.dart';
import 'package:flutter_app/core/services/notification_manager.dart';
import 'package:flutter_app/features/notifications/views/notification_center_page.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // Add WidgetsBindingObserver mixin
  final _mongoDBService = MongoDBService();
  Uint8List? _profilePhotoData;

  void _handleTrackersShowcase(BuildContext context) {
    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);
    tourProvider.completeCurrentStep();

    // Trigger the next showcase step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShowcaseView.get().startShowCase([TourKeys.dailyTipsKey]);
    });
  }

  void _handleDailyTipsShowcase(BuildContext context) {
    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);
    tourProvider.completeCurrentStep();

    // Trigger the next showcase step (My Plan button)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          ShowcaseView.get().startShowCase([TourKeys.myPlanButtonKey]);
        } catch (e) {}
      });
    });
  }

  // Flag to prevent duplicate initial data loads on first build
  bool _isInitialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    // Register for app lifecycle events. This enables didChangeAppLifecycleState.
    WidgetsBinding.instance.addObserver(this);

    // Using addPostFrameCallback to ensure context is available and avoid blocking build.
    // This will trigger the first data load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialLoadComplete) {
        _isInitialLoadComplete = true; // Mark as started
        _loadDataForRefresh(); // Initial data load
        _loadProfilePhoto(); // Profile photo loads once
        _initializeNotificationManager(); // Initialize notification manager
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    // REQUIRED: Unsubscribe from observers to prevent memory leaks
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // --- WidgetsBindingObserver Methods ---
  // Called when the application's lifecycle state changes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the app comes back to the foreground from background, only refresh tips if needed.
    if (state == AppLifecycleState.resumed) {
      print('App resumed. Only refreshing tips if needed.');
      _loadTipsIfNeeded();
    }
  }

  // --- Consolidated Data Loading Method ---
  // This method will be called for initial load and on refreshes.
  Future<void> _loadDataForRefresh() async {
    // Avoid re-loading if a load is already in progress
    final trackerProvider =
        Provider.of<TrackerProvider>(context, listen: false);
    final tipProvider = Provider.of<TipProvider>(context, listen: false);
    final authProvider = Provider.of<AuthController>(context, listen: false);

    if (trackerProvider.isLoading || tipProvider.isLoading) {
      print('Data already loading, skipping refresh.');
      return;
    }

    final user = authProvider.currentUser;
    if (user != null && user.id != null) {
      final dietType = user.dietType ?? 'MyPlate';

      // Load Trackers - use personalized diet plan if available
      final personalizedDietPlan = user.selectedDietPlan;
      await trackerProvider.loadUserTrackers(user.id!, dietType,
          personalizedDietPlan: personalizedDietPlan);

      // Load Tips (can be run in parallel or after trackers)
      await tipProvider.initializeTips(user.medicalConditions ?? [], user.id!);
    } else {
      print('User not logged in, cannot load trackers or tips.');
      // Optionally, clear existing data if user logs out or session expires
      // trackerProvider.clearError(); // Moved to TrackerProvider fix
      // You might want to reset tracker/tip state here if user data is absent
    }
  }

  // --- Lightweight Tips Loading Method ---
  // This method only loads tips without touching trackers to prevent unnecessary UI refreshes
  Future<void> _loadTipsIfNeeded() async {
    final tipProvider = Provider.of<TipProvider>(context, listen: false);
    final authProvider = Provider.of<AuthController>(context, listen: false);

    if (tipProvider.isLoading) {
      print('Tips already loading, skipping refresh.');
      return;
    }

    final user = authProvider.currentUser;
    if (user != null && user.id != null) {
      // Only load tips, not trackers
      await tipProvider.initializeTips(user.medicalConditions ?? [], user.id!);
    } else {
      print('User not logged in, cannot load tips.');
    }
  }

  // Existing method for initial profile photo load (doesn't need frequent refresh)
  Future<void> _loadProfilePhoto() async {
    final authProvider = Provider.of<AuthController>(context, listen: false);
    final photoId = authProvider.currentUser?.profilePhotoId;

    if (photoId != null) {
      try {
        final photoData = await _mongoDBService.getProfilePhoto(photoId);
        if (photoData != null && mounted) {
          setState(() {
            _profilePhotoData = Uint8List.fromList(photoData);
          });
        }
      } catch (e) {
        print(
            'Error loading profile photo: $e'); // Log error instead of throwing
        if (mounted) {
          // Optionally show a placeholder or error icon
          setState(() {
            _profilePhotoData = null; // Clear photo on error
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _profilePhotoData = null; // Clear if no photo ID
        });
      }
    }
  }

  // Initialize notification manager
  Future<void> _initializeNotificationManager() async {
    try {
      final authProvider = Provider.of<AuthController>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId != null) {
        final notificationManager =
            Provider.of<NotificationManager>(context, listen: false);
        await notificationManager.initialize(userId);
        await notificationManager.loadNotifications();
      }
    } catch (e) {
      debugPrint('Error initializing notification manager: $e');
    }
  }

  // Existing method for tip tap handling
  Future<void> _handleTipTap(Tip tip) async {
    final authProvider = Provider.of<AuthController>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      final tipProvider = Provider.of<TipProvider>(context, listen: false);
      await tipProvider.markTipAsViewed(tip.id, user.id!);
    }
  }

  // >>> THIS METHOD IS NOW CORRECTLY PLACED INSIDE _HomePageState <<<
  Widget _buildTipCard(
    BuildContext context,
    String title,
    String description,
    String imageUrl, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Image
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image(
                    image: ImageCacheService().getImageProvider(imageUrl),
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 250,
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 250,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        if (onTap != null) onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image(
                image: ImageCacheService().getImageProvider(imageUrl),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthController>(context);
    final user = authProvider.currentUser;
    final dietType =
        user?.dietType ?? 'MyPlate'; // Default to MyPlate if not specified

    return Consumer<ForcedTourProvider>(
      builder: (context, tourProvider, child) {
        Widget content = Scaffold(
          backgroundColor: const Color(0xFFF7F7F8),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: _profilePhotoData != null
                                  ? MemoryImage(_profilePhotoData!)
                                  : const AssetImage(
                                          'assets/images/profile_pic.png')
                                      as ImageProvider,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hi, Good Morning',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  authProvider.currentUser?.name ?? 'Guest',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Consumer<NotificationManager>(
                              builder: (context, notificationManager, child) {
                                final unreadCount =
                                    notificationManager.unreadCount;
                                return Stack(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                          Icons.notifications_outlined),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const NotificationCenterPage(),
                                          ),
                                        );
                                      },
                                      onLongPress: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const NotificationTestingPage(),
                                          ),
                                        );
                                      },
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout),
                              onPressed: () async {
                                try {
                                  await authProvider.logout();
                                  if (mounted) {
                                    Navigator.of(context)
                                        .pushNamedAndRemoveUntil(
                                      '/login',
                                      (route) => false,
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Logout failed: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Trackers section
                  if (user != null && user.id != null)
                    Showcase(
                      key: TourKeys.trackersKey,
                      title: 'Track Your Nutrition',
                      description:
                          'This is where you track your daily nutrition goals. You\'ll see how well you\'re following your personalized meal plan.',
                      targetShapeBorder: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      tooltipBackgroundColor: Colors.white,
                      textColor: Colors.black,
                      overlayColor: Colors.black54,
                      overlayOpacity: 0.8,
                      onTargetClick: () {
                        _handleTrackersShowcase(context);
                      },
                      onToolTipClick: () {
                        _handleTrackersShowcase(context);
                      },
                      disposeOnTap: false,
                      child: Consumer<TrackerProvider>(
                        builder: (context, trackerProvider, child) {
                          return TrackerGrid(
                              userId: user.id!, dietType: dietType);
                        },
                      ),
                    ),

                  // Activity section could go here

                  // Daily Tips Section - horizontal scrollable view
                  Builder(
                    builder: (context) {
                      return Showcase(
                        key: TourKeys.dailyTipsKey,
                        title: 'Daily Health Tips',
                        description:
                            'Get personalized health tips and recommendations based on your condition and goals.',
                        targetShapeBorder: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        tooltipBackgroundColor: Colors.white,
                        textColor: Colors.black,
                        overlayColor: Colors.black54,
                        overlayOpacity: 0.8,
                        onTargetClick: () {
                          _handleDailyTipsShowcase(context);
                        },
                        onToolTipClick: () {
                          _handleDailyTipsShowcase(context);
                        },
                        disposeOnTap: false,
                        child: Consumer<TipProvider>(
                          builder: (context, tipProvider, child) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Daily tips',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (tipProvider.isLoading)
                                    const SizedBox(
                                      height: 201,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  else if (tipProvider.shownTips.isEmpty)
                                    const SizedBox(
                                      height: 201,
                                      child: Center(
                                        child: Text('No tips available'),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      height: 201,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: tipProvider.shownTips.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(width: 16),
                                        itemBuilder: (context, index) {
                                          final tip =
                                              tipProvider.shownTips[index];
                                          return SizedBox(
                                            width: 216,
                                            child: _buildTipCard(
                                              context,
                                              tip.title,
                                              tip.description,
                                              tip.imageUrl,
                                              onTap: () => _handleTipTap(tip),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        return content;
      },
    );
  }
}

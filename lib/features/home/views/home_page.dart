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
import 'package:flutter_app/features/tracking/services/tracker_service.dart';
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
  String? _lastDietType; // Track last diet type to detect changes
  bool _isDisposed = false;

  void _handleTrackersShowcase(BuildContext context) {
    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);
    tourProvider.completeCurrentStep();

    // Trigger the next showcase step (info icon on first tracker)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShowcaseView.get().startShowCase([TourKeys.trackerInfoKey]);
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

  // Track last diet plan to detect changes (even if dietType stays the same)
  int? _lastTargetCalories;
  Map<String, dynamic>? _lastSelectedDietPlan;

  // Map myPlanType to tracker dietType
  // According to the diet assignment matrix:
  // - When diabetes is detected, the matrix assigns diet: "DASH"
  // - myPlanType is set to 'DiabetesPlate' for display/education purposes
  // - But the actual dietType returned is 'DASH', so DiabetesPlate users get DASH trackers
  // - Regular users: myPlanType == dietType (DASH or MyPlate)
  String _mapMyPlanTypeToDietType(String? planType) {
    if (planType == null) return 'MyPlate';
    if (planType == 'DASH') return 'DASH';
    if (planType == 'DiabetesPlate')
      return 'DASH'; // DiabetesPlate uses DASH trackers (per matrix rules)
    if (planType == 'MyPlate') return 'MyPlate';
    // Default fallback
    return 'MyPlate';
  }

  // Helper to check if diet plan values have changed
  bool _hasDietPlanChanged(
      Map<String, dynamic>? oldPlan, Map<String, dynamic>? newPlan) {
    if (oldPlan == null && newPlan == null) return false;
    if (oldPlan == null || newPlan == null) return true;

    // Compare key values that affect tracker goals
    // Check important fields like servings, calories, sodium, etc.
    final keysToCheck = [
      'targetCalories',
      'grains',
      'vegetables',
      'fruits',
      'protein',
      'dairy',
      'sodium'
    ];

    for (final key in keysToCheck) {
      final oldValue = oldPlan[key];
      final newValue = newPlan[key];

      // Handle numeric comparison
      if (oldValue is num && newValue is num) {
        if ((oldValue - newValue).abs() > 0.01) return true;
      } else if (oldValue != newValue) {
        return true;
      }
    }

    return false;
  }

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
        final authProvider =
            Provider.of<AuthController>(context, listen: false);
        final user = authProvider.currentUser;
        _lastDietType =
            _mapMyPlanTypeToDietType(user?.myPlanType ?? user?.dietType);
        _lastTargetCalories = user?.targetCalories;
        _lastSelectedDietPlan = user?.selectedDietPlan != null
            ? Map<String, dynamic>.from(user!.selectedDietPlan!)
            : null;
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
    _isDisposed = true;
    super.dispose();
  }

  // --- WidgetsBindingObserver Methods ---
  // Called when the application's lifecycle state changes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the app comes back to the foreground from background, only refresh tips if needed.
    if (state == AppLifecycleState.resumed) {
      _loadTipsIfNeeded();
    }
  }

  // --- Consolidated Data Loading Method ---
  // This method will be called for initial load and on refreshes.
  Future<void> _loadDataForRefresh() async {
    // Check if widget is still mounted before proceeding
    if (!mounted || _isDisposed) {
      print('Widget disposed, skipping data refresh');
      return;
    }

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
      // Map myPlanType to tracker dietType
      // According to diet assignment matrix: DiabetesPlate users get DASH diet
      // myPlanType can be "DASH", "MyPlate", or "DiabetesPlate"
      // For trackers: DiabetesPlate -> DASH, MyPlate -> MyPlate, DASH -> DASH
      String? myPlanType = user.myPlanType;
      final dietType =
          _mapMyPlanTypeToDietType(myPlanType ?? user.dietType ?? 'MyPlate');

      // Check if diet type has changed from last known value
      if (_lastDietType != null && _lastDietType != dietType) {
        print(
            '🔄 Diet type changed from $_lastDietType to $dietType. Clearing cache.');
        // Clear tracker state when diet type changes
        trackerProvider.clearTrackers();
      }

      // Update last diet type only if still mounted
      if (mounted && !_isDisposed) {
        _lastDietType = dietType;
      }

      // Load Trackers - use personalized diet plan if available
      final personalizedDietPlan = user.selectedDietPlan;
      print('📋 Loading trackers for userId: ${user.id}, dietType: $dietType');

      // Check if this is a forced reload (plan changed)
      // If trackers were cleared due to plan change, force reload
      final forceReload = trackerProvider.dailyTrackers.isEmpty &&
          trackerProvider.weeklyTrackers.isEmpty &&
          _isInitialLoadComplete;

      await trackerProvider.loadUserTrackers(user.id!, dietType,
          personalizedDietPlan: personalizedDietPlan, forceReload: forceReload);

      // Check mounted again before loading tips
      if (!mounted || _isDisposed) return;

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
      return;
    }

    final user = authProvider.currentUser;
    if (user != null && user.id != null) {
      // Only load tips, not trackers
      await tipProvider.initializeTips(user.medicalConditions ?? [], user.id!);
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

  // Returns a time-based greeting using the device's local time
  String _timeBasedGreeting() {
    final int hour = DateTime.now().hour;
    // Night: 21:00–04:59, Morning: 05:00–11:59, Afternoon: 12:00–16:59, Evening: 17:00–20:59
    if (hour >= 5 && hour < 12) return 'Hi, Good Morning';
    if (hour >= 12 && hour < 17) return 'Hi, Good Afternoon';
    if (hour >= 17 && hour < 21) return 'Hi, Good Evening';
    return 'Hi, Good Night';
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
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF6A00)),
                          ),
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
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                      ),
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
    return Consumer<AuthController>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        // Map myPlanType to tracker dietType (DiabetesPlate -> MyPlate)
        final dietType =
            _mapMyPlanTypeToDietType(user?.myPlanType ?? user?.dietType);

        // Get current diet plan values
        final currentTargetCalories = user?.targetCalories;
        final currentSelectedDietPlan = user?.selectedDietPlan;

        // Check if diet type has changed OR if diet plan has changed (calorie/plan updates)
        final dietTypeChanged = _lastDietType != null &&
            _lastDietType != dietType &&
            _isInitialLoadComplete &&
            !_isDisposed;

        // Check if calorie plan changed (targetCalories or selectedDietPlan changed)
        final planChanged = _isInitialLoadComplete &&
            !_isDisposed &&
            (_lastTargetCalories != currentTargetCalories ||
                _hasDietPlanChanged(
                    _lastSelectedDietPlan, currentSelectedDietPlan));

        if (dietTypeChanged || planChanged) {
          // Update tracked values immediately to prevent duplicate reloads
          if (dietTypeChanged) {
            _lastDietType = dietType;
          }

          if (planChanged) {
            _lastTargetCalories = currentTargetCalories;
            _lastSelectedDietPlan = currentSelectedDietPlan != null
                ? Map<String, dynamic>.from(currentSelectedDietPlan)
                : null;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted || _isDisposed) return;
            // Clear old tracker cache and force reload
            final trackerProvider =
                Provider.of<TrackerProvider>(context, listen: false);
            final authProvider =
                Provider.of<AuthController>(context, listen: false);
            final user = authProvider.currentUser;

            // Clear trackers and cache first
            trackerProvider.clearTrackers();
            if (user?.id != null) {
              // Clear cache to force fresh load
              final trackerService = TrackerService();
              await trackerService.clearUserTrackerCache(user!.id!);

              // Wait a moment to ensure cache is cleared
              await Future.delayed(const Duration(milliseconds: 100));
            }

            // Reload with new diet type and plan (force reload)
            if (mounted && !_isDisposed) {
              final personalizedDietPlan = user?.selectedDietPlan;
              final dietType =
                  _mapMyPlanTypeToDietType(user?.myPlanType ?? user?.dietType);
              await trackerProvider.loadUserTrackers(
                user!.id!,
                dietType,
                personalizedDietPlan: personalizedDietPlan,
                forceReload: true,
              );
            }
          });
        } else {
          // Initialize tracked values on first load
          if (_lastDietType == null && !_isDisposed) {
            _lastDietType = dietType;
          }
          if (_lastTargetCalories == null && !_isDisposed) {
            _lastTargetCalories = currentTargetCalories;
            _lastSelectedDietPlan = currentSelectedDietPlan != null
                ? Map<String, dynamic>.from(currentSelectedDietPlan)
                : null;
          }
        }

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
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(context, '/profile');
                                  },
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: _profilePhotoData != null
                                        ? MemoryImage(_profilePhotoData!)
                                        : const AssetImage(
                                                'assets/images/profile_pic.png')
                                            as ImageProvider,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _timeBasedGreeting(),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      user?.name ?? 'Guest',
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
                                  builder:
                                      (context, notificationManager, child) {
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
                                            // NotificationTestingPage removed - simplified notification system
                                          },
                                        ),
                                        if (unreadCount > 0)
                                          Positioned(
                                            right: 8,
                                            top: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
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
                          tooltipPosition: TooltipPosition.bottom,
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
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            child: CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Color(0xFFFF6A00)),
                                            ),
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
                                            itemCount:
                                                tipProvider.shownTips.length,
                                            separatorBuilder:
                                                (context, index) =>
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
                                                  onTap: () =>
                                                      _handleTipTap(tip),
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
      },
    );
  }
}

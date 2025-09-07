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
import 'package:flutter_app/main.dart'; // REQUIRED: Import main.dart to access the global routeObserver

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, RouteAware {
  // Add WidgetsBindingObserver and RouteAware mixins
  final _mongoDBService = MongoDBService();
  Uint8List? _profilePhotoData;
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
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to RouteAware. This enables didPopNext.
    // Make sure 'routeObserver' is available from main.dart.
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route is PageRoute) {
      // Ensure it's a PageRoute for RouteAware
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // REQUIRED: Unsubscribe from observers to prevent memory leaks
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // --- WidgetsBindingObserver Methods ---
  // Called when the application's lifecycle state changes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the app comes back to the foreground from background, reload data.
    if (state == AppLifecycleState.resumed) {
      print('App resumed. Reloading tracker and tip data.');
      _loadDataForRefresh();
    }
  }

  // --- RouteAware Methods ---
  // Called when this route is popped, and the top-most route is now this route.
  // This happens when navigating back to HomePage from another screen within the app.
  @override
  void didPopNext() {
    print('Navigated back to Home page. Reloading tracker and tip data.');
    _loadDataForRefresh();
  }

  // Other RouteAware methods (can be left empty if no specific action is needed)
  @override
  void didPush() {}
  @override
  void didPop() {}
  @override
  void didPushNext() {}

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

      // Load Trackers - always use loadUserTrackers to preserve existing progress
      await trackerProvider.loadUserTrackers(user.id!, dietType);

      // Load Tips (can be run in parallel or after trackers)
      await tipProvider.initializeTips(user.medicalConditions ?? [], user.id!);
    } else {
      print('User not logged in, cannot load trackers or tips.');
      // Optionally, clear existing data if user logs out or session expires
      // trackerProvider.clearError(); // Moved to TrackerProvider fix
      // You might want to reset tracker/tip state here if user data is absent
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
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
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
    final tipProvider = context.watch<TipProvider>();
    final trackerProvider = context.watch<TrackerProvider>();
    final user = authProvider.currentUser;
    final dietType =
        user?.dietType ?? 'MyPlate'; // Default to MyPlate if not specified

    return Scaffold(
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
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () async {
                            try {
                              await authProvider.logout();
                              if (mounted) {
                                Navigator.of(context).pushNamedAndRemoveUntil(
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
                TrackerGrid(userId: user.id!, dietType: dietType),

              // Activity section could go here

              // Daily Tips Section
              Padding(
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
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else if (tipProvider.shownTips.isEmpty)
                      const Center(
                        child: Text('No tips available'),
                      )
                    else
                      ...tipProvider.shownTips.map((tip) {
                        return Column(
                          children: [
                            _buildTipCard(
                              context,
                              tip.title,
                              tip.description,
                              tip.imageUrl,
                              onTap: () => _handleTipTap(tip),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

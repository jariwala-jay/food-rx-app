import 'package:flutter/material.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/home/providers/tip_provider.dart';
import 'package:flutter_app/features/home/models/tip.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:flutter_app/core/services/image_cache_service.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/features/tracking/views/tracker_grid.dart';
import 'package:flutter_app/features/tracking/controller/tracker_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _mongoDBService = MongoDBService();
  Uint8List? _profilePhotoData;

  @override
  void initState() {
    super.initState();
    _initializeTips();
    _loadProfilePhoto();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTrackers();
    });
  }

  Future<void> _initializeTips() async {
    final authProvider = Provider.of<AuthController>(context, listen: false);
    final user = authProvider.currentUser;

    if (user != null) {
      final medicalConditions = user.medicalConditions ?? [];
      final tipProvider = Provider.of<TipProvider>(context, listen: false);
      await tipProvider.initializeTips(medicalConditions, user.id!);
    }
  }

  Future<void> _initializeTrackers() async {
    final authProvider = Provider.of<AuthController>(context, listen: false);
    final user = authProvider.currentUser;

    if (user != null && user.id != null) {
      final trackerProvider =
          Provider.of<TrackerProvider>(context, listen: false);
      final dietType =
          user.dietType ?? 'MyPlate'; // Default to MyPlate if not specified

      // Only call loadUserTrackers, which will handle initialization if needed
      // This avoids duplicate initialization calls
      await trackerProvider.loadUserTrackers(user.id!, dietType);
    }
  }

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
        throw Exception(e);
      }
    }
  }

  Future<void> _handleTipTap(Tip tip) async {
    final authProvider = Provider.of<AuthController>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      final tipProvider = Provider.of<TipProvider>(context, listen: false);
      await tipProvider.markTipAsViewed(tip.id, user.id!);
    }
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
}

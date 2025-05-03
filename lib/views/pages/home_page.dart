import 'package:flutter/material.dart';
import 'package:flutter_app/providers/auth_provider.dart';
import 'package:flutter_app/providers/tip_provider.dart';
import 'package:flutter_app/models/tip.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../../services/image_cache_service.dart';
import '../../services/mongodb_service.dart';
import '../../widgets/recommended_articles_section.dart';

class CustomNavBarShape extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    const double cornerRadius = 20;
    final double centerWidth = size.width * 0.25; // Increased from 0.20 to 0.25
    final double centerStartPosition = (size.width - centerWidth) / 2;
    const double centerCurveHeight = 20; // Increased from 15 to 20

    Path path = Path()
      // Start from top-left with rounded corner
      ..moveTo(cornerRadius, 0)
      ..lineTo(centerStartPosition, 0)
      // Left curve of center cutout
      ..quadraticBezierTo(
        centerStartPosition + centerWidth * 0.2,
        0,
        centerStartPosition + centerWidth * 0.2,
        centerCurveHeight,
      )
      // Bottom curve of center cutout
      ..quadraticBezierTo(
        centerStartPosition + (centerWidth * 0.5),
        centerCurveHeight * 2.2, // Increased curve depth
        centerStartPosition + centerWidth * 0.8,
        centerCurveHeight,
      )
      // Right curve of center cutout
      ..quadraticBezierTo(
        centerStartPosition + centerWidth,
        0,
        centerStartPosition + centerWidth,
        0,
      )
      // Top-right rounded corner
      ..lineTo(size.width - cornerRadius, 0)
      ..quadraticBezierTo(
        size.width,
        0,
        size.width,
        cornerRadius,
      )
      // Bottom-right rounded corner
      ..lineTo(size.width, size.height - cornerRadius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - cornerRadius,
        size.height,
      )
      // Bottom-left rounded corner
      ..lineTo(cornerRadius, size.height)
      ..quadraticBezierTo(
        0,
        size.height,
        0,
        size.height - cornerRadius,
      )
      ..lineTo(0, cornerRadius)
      // Top-left rounded corner completion
      ..quadraticBezierTo(
        0,
        0,
        cornerRadius,
        0,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomNavBarShape oldDelegate) => false;
}

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
  }

  Future<void> _initializeTips() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user != null) {
      final medicalConditions = user.medicalConditions ?? [];
      final tipProvider = Provider.of<TipProvider>(context, listen: false);
      await tipProvider.initializeTips(medicalConditions, user.id!);
    }
  }

  Future<void> _loadProfilePhoto() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      final tipProvider = Provider.of<TipProvider>(context, listen: false);
      await tipProvider.markTipAsViewed(tip.id, user.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final tipProvider = context.watch<TipProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Row(
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
                const SizedBox(height: 24),

                // Recommended Articles Section
                const RecommendedArticlesSection(),
                const SizedBox(height: 24),

                // Daily Tips Section
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

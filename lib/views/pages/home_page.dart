import 'package:flutter/material.dart';
import 'package:flutter_app/models/article.dart';
import 'package:flutter_app/providers/auth_service.dart';
import 'package:flutter_app/views/pages/article_detail_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _buildRecommendedCard(
      BuildContext context, String title, String imagePath) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailPage(
              article: Article(
                title: title,
                category: 'Healthy Lifestyle',
                imageUrl: imagePath,
              ),
            ),
          ),
        );
      },
      child: Container(
        width: 280,
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
              child: Image.asset(
                imagePath,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(BuildContext context, String title, String description,
      String imagePath) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailPage(
              article: Article(
                title: title,
                category: 'Daily Tips',
                imageUrl: imagePath,
              ),
            ),
          ),
        );
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
              child: Image.asset(
                imagePath,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
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
    final authService = context.watch<AuthService>();

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
                        const CircleAvatar(
                          radius: 20,
                          backgroundImage:
                              AssetImage('assets/images/profile_pic.png'),
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
                              authService.email ?? 'Wilson Barly',
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
                          onPressed: () {
                            authService.logout();
                            Navigator.of(context)
                                .pushReplacementNamed('/login');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Recommended Section
                const Text(
                  'Recommended',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildRecommendedCard(
                        context,
                        'What is High Blood Pressure?',
                        'assets/images/blood_pressure.png',
                      ),
                      const SizedBox(width: 16),
                      _buildRecommendedCard(
                        context,
                        'Healthy Diet Tips',
                        'assets/images/healthy_diet.png',
                      ),
                    ],
                  ),
                ),

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
                _buildTipCard(
                  context,
                  'Tip 1',
                  'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do',
                  'assets/images/tip1.png',
                ),
                const SizedBox(height: 16),
                _buildTipCard(
                  context,
                  'Tip 2',
                  'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do',
                  'assets/images/tip2.png',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

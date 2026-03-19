import 'package:flutter/material.dart';
import 'package:flutter_app/features/education/views/education_plan_video_page.dart';

/// Card shown as the first item in Recommended section to watch the plan video.
/// Uses the first screenshot from each plan folder as the thumbnail.
class PlanVideoCard extends StatelessWidget {
  final String planType; // 'DiabetesPlate' | 'DASH' | 'MyPlate'
  final String title;

  const PlanVideoCard({
    Key? key,
    required this.planType,
    required this.title,
  }) : super(key: key);

  String _thumbnailPath() {
    switch (planType) {
      case 'DASH':
        return 'assets/nutrition/screenshots/dash/1.png';
      case 'MyPlate':
        return 'assets/nutrition/screenshots/myplate/1.png';
      case 'DiabetesPlate':
        return 'assets/nutrition/screenshots/diabetes_plate/1.png';
      default:
        return 'assets/nutrition/screenshots/myplate/1.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EducationPlanVideoPage(
              planType: planType,
              title: title,
            ),
          ),
        );
      },
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      _thumbnailPath(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFFF6A00).withOpacity(0.7),
                      ),
                    ),
                    // Dark overlay so play icon stands out
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.videocam, color: const Color(0xFFFF6A00), size: 20 * clampedScale),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16 * clampedScale,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';

/// Page that displays portion size guide images with title "Portion Size Details".
/// Shown when user taps the hand icon next to My Plan button.
class PortionSizeDetailsPage extends StatefulWidget {
  const PortionSizeDetailsPage({super.key});

  @override
  State<PortionSizeDetailsPage> createState() => _PortionSizeDetailsPageState();
}

class _PortionSizeDetailsPageState extends State<PortionSizeDetailsPage> {
  List<({String path, String label})> _imagesForPlan(String? myPlanType) {
    final plan = (myPlanType ?? 'MyPlate').trim();
    final upper = plan.toUpperCase();

    // DiabetesPlate plan
    if (plan == 'DiabetesPlate') {
      return const [
        (
          path:
              'assets/nutrition/screenshots/Portion_sizes/Diabetes_portion_size.png',
          label: 'Diabetes Plate Portion Sizes',
        ),
      ];
    }

    // DASH diet plan
    if (upper == 'DASH') {
      return const [
        (
          path:
              'assets/nutrition/screenshots/Portion_sizes/Dash_portion_size.png',
          label: 'DASH Portion Sizes',
        ),
      ];
    }

    // Default to MyPlate portion size images
    return const [
      (
        path:
            'assets/nutrition/screenshots/Portion_sizes/MyPlate_portion_size.png',
        label: 'MyPlate Portion Sizes',
      ),
    ];
  }

  int _currentPage = 0;

  void _nextPage() {
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.currentUser;
    final planType = user?.myPlanType ?? user?.dietType ?? 'MyPlate';
    final images = _imagesForPlan(planType);
    if (_currentPage < images.length - 1) {
      setState(() => _currentPage++);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.currentUser;
    final planType = user?.myPlanType ?? user?.dietType ?? 'MyPlate';
    final images = _imagesForPlan(planType);

    if (_currentPage >= images.length) {
      _currentPage = 0;
    }

    final item = images[_currentPage];
    final isLastPage = _currentPage >= images.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Portion Size Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  item.path,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image_not_supported,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Image not found: ${item.label}',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                mainAxisAlignment: _currentPage > 0
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.center,
                children: [
                  if (_currentPage > 0)
                    ElevatedButton(
                      onPressed: _previousPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Previous'),
                    ),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(isLastPage ? 'Done' : 'Next'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

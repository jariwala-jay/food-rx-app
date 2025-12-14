import 'package:flutter/material.dart';
import 'package:flutter_app/core/utils/app_colors.dart';
import 'package:flutter_app/core/utils/typography.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Total pages: 1 intro + 5 features = 6
  final int _totalPages = 6;

  final List<OnboardingItem> _featureItems = [
    OnboardingItem(
      imagePath: 'assets/onboarding/assessment.png',
      title: 'Assessment',
      description:
          'The assessment will ask you to provide the information needed to create your personalized plan and generate resources to best meet your needs.',
    ),
    OnboardingItem(
      imagePath: 'assets/onboarding/pantry.png',
      title: 'Food Inventory',
      description:
          'The food inventory is where you will log the foods you receive from the Food Pharmacy and other items you have available at home. The inventory will help you keep track of your food items and will be used to generate recipes.',
    ),
    OnboardingItem(
      imagePath: 'assets/onboarding/recipes.png',
      title: 'Recipe Generator',
      description:
          'The recipe generator will use the information from your assessment and food inventory to create a list of easy-to-make and delicious meals tailored to improve your health.',
    ),
    OnboardingItem(
      imagePath: 'assets/onboarding/tracker.png',
      title: 'Tracker',
      description:
          'The tracker will allow you to see how much you\'ve eaten throughout the day and help you stay on track with your personalized food-as-medicine plan.',
    ),
    OnboardingItem(
      imagePath: 'assets/onboarding/education.png',
      title: 'Education',
      description:
          'The education section will provide personalized information and resources to help you improve your health and reach your goals.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Carousel Section
              Expanded(
                child: _buildCarousel(),
              ),

              const SizedBox(height: 16),

              // Page Indicators
              _buildPageIndicators(),

              const SizedBox(height: 24),

              // Buttons
              _buildButtons(context),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
      },
      itemCount: _totalPages,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildWelcomeSlide();
        }
        return _buildFeatureCard(_featureItems[index - 1]);
      },
    );
  }

  Widget _buildWelcomeSlide() {
    // Clamp text scale factor to prevent overflow with accessibility settings
    final textScaleFactor =
        MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.3);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Logo
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/icons/myfoodrx_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Welcome to MyFoodRx!',
              style: AppTypography.bg_22_b.copyWith(
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 16),

            // First paragraph
            Text(
              'This app is designed to give you a personalized approach to maximizing the benefits of using food-as-medicine to improve your health.',
              textAlign: TextAlign.center,
              style: AppTypography.bg_14_r.copyWith(
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Second paragraph
            Text(
              'As you use this app, you will receive a personalized meal plan and recipes tailored to your health conditions, health goals, and food and cooking preferences.',
              textAlign: TextAlign.center,
              style: AppTypography.bg_14_r.copyWith(
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Components intro
            Text(
              'The app has five main components:',
              textAlign: TextAlign.center,
              style: AppTypography.bg_14_sb.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Swipe hint
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swipe_left_rounded,
                  size: 18,
                  color: AppColors.primaryOrange.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  'Swipe to explore',
                  style: AppTypography.bg_12_r.copyWith(
                    color: AppColors.primaryOrange.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(OnboardingItem item) {
    // Clamp text scale factor to prevent overflow with accessibility settings
    final textScaleFactor =
        MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.3);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: Column(
        children: [
          // Screenshot Card
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  item.imagePath,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholder(item.title);
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            item.title,
            style: AppTypography.bg_16_sb.copyWith(
              color: AppColors.primaryOrange,
            ),
          ),

          const SizedBox(height: 6),

          // Description
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Text(
                item.description,
                textAlign: TextAlign.center,
                style: AppTypography.bg_14_r.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    IconData icon;
    Color iconColor;

    switch (title) {
      case 'Assessment':
        icon = Icons.assignment_outlined;
        iconColor = const Color(0xFF4CAF50);
        break;
      case 'Food Inventory':
        icon = Icons.kitchen_outlined;
        iconColor = const Color(0xFF2196F3);
        break;
      case 'Recipe Generator':
        icon = Icons.restaurant_menu_outlined;
        iconColor = AppColors.primaryOrange;
        break;
      case 'Tracker':
        icon = Icons.track_changes_outlined;
        iconColor = const Color(0xFF9C27B0);
        break;
      case 'Education':
        icon = Icons.school_outlined;
        iconColor = const Color(0xFFFF5722);
        break;
      default:
        icon = Icons.apps;
        iconColor = AppColors.primaryOrange;
    }

    return Container(
      color: AppColors.backgroundLight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTypography.bg_16_sb.copyWith(color: iconColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _totalPages,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _currentPage == index
                ? AppColors.primaryOrange
                : AppColors.borderLight,
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/signup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Text(
              'Sign Up',
              style: AppTypography.bg_16_sb.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryOrange,
              side:
                  const BorderSide(color: AppColors.primaryOrange, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Text(
              'Log In',
              style: AppTypography.bg_16_sb
                  .copyWith(color: AppColors.primaryOrange),
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingItem {
  final String imagePath;
  final String title;
  final String description;

  OnboardingItem({
    required this.imagePath,
    required this.title,
    required this.description,
  });
}

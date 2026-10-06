import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_app/core/utils/app_colors.dart';
import 'package:flutter_app/core/utils/typography.dart';

/// Full-screen loading state shown while `AuthController.isLoading` is true.
/// Matches the native launch screen (same logo, size and background) so the
/// hand-off from native to Flutter doesn't visibly change.
class StartupLoadingScreen extends StatefulWidget {
  const StartupLoadingScreen({super.key, required this.showStartupMessage});

  /// Only the first app/session load should show the message; later
  /// `isLoading` operations (login, Google sign-in, profile updates) reuse
  /// this screen without it.
  final bool showStartupMessage;

  // Reuses the native iOS launch image directly (declared in pubspec.yaml)
  // so the logo can't drift from the launch screen and isn't duplicated.
  static const logoAsset =
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png';

  static const messageDelay = Duration(seconds: 3);
  static const messageText = 'Starting up, one moment…';

  @override
  State<StartupLoadingScreen> createState() => _StartupLoadingScreenState();
}

class _StartupLoadingScreenState extends State<StartupLoadingScreen> {
  // Same sizing rule as LaunchScreen.storyboard: 200x108 logo, at most 60% of
  // the screen width.
  static const _logoWidth = 200.0;
  static const _logoAspect = 108 / 200;
  static const _logoMaxWidthFraction = 0.6;
  static const _messageGap = 24.0;

  Timer? _messageTimer;
  bool _showMessage = false;

  @override
  void initState() {
    super.initState();
    if (widget.showStartupMessage) {
      _messageTimer = Timer(StartupLoadingScreen.messageDelay, () {
        if (mounted) setState(() => _showMessage = true);
      });
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoWidth = math.min(
      _logoWidth,
      MediaQuery.sizeOf(context).width * _logoMaxWidthFraction,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Center(
              child: Image.asset(
                StartupLoadingScreen.logoAsset,
                width: logoWidth,
                fit: BoxFit.contain,
                semanticLabel: 'MyFoodRx',
              ),
            ),
            if (_showMessage)
              // Positioned from the screen centre so the logo stays exactly
              // where the native launch screen drew it.
              Positioned(
                top: constraints.maxHeight / 2 +
                    logoWidth * _logoAspect / 2 +
                    _messageGap,
                left: 24,
                right: 24,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      StartupLoadingScreen.messageText,
                      textAlign: TextAlign.center,
                      style: AppTypography.bg_14_r
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

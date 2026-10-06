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
  static const messageText = 'Getting things ready…';

  @override
  State<StartupLoadingScreen> createState() => _StartupLoadingScreenState();
}

class _StartupLoadingScreenState extends State<StartupLoadingScreen>
    with SingleTickerProviderStateMixin {
  // Same sizing rule as LaunchScreen.storyboard: 200x108 logo, at most 60% of
  // the screen width.
  static const _logoWidth = 200.0;
  static const _logoAspect = 108 / 200;
  static const _logoMaxWidthFraction = 0.6;
  static const _messageGap = 24.0;

  // One highlight sweep (~2.3s) followed by a short rest, then repeat.
  static const _shimmerCycle = Duration(milliseconds: 3000);
  static const _shimmerSweepFraction = 2300 / 3000;
  // Highlight width as a fraction of the text width.
  static const _shimmerBandWidth = 0.35;

  late final AnimationController _shimmer =
      AnimationController(vsync: this, duration: _shimmerCycle);

  Timer? _messageTimer;
  bool _showMessage = false;

  @override
  void initState() {
    super.initState();
    if (widget.showStartupMessage) {
      _messageTimer = Timer(StartupLoadingScreen.messageDelay, () {
        if (!mounted) return;
        setState(() => _showMessage = true);
        if (!MediaQuery.disableAnimationsOf(context)) _shimmer.repeat();
      });
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _shimmer.dispose();
    super.dispose();
  }

  Widget _buildMessage(BuildContext context) {
    final text = Text(
      StartupLoadingScreen.messageText,
      textAlign: TextAlign.center,
      style: AppTypography.bg_14_m.copyWith(color: AppColors.textPrimary),
    );
    // The text stays fully visible; only a brand-colored highlight passes
    // over it. Static when the OS asks to reduce motion.
    if (MediaQuery.disableAnimationsOf(context)) return Center(child: text);

    return Center(
      child: AnimatedBuilder(
        animation: _shimmer,
        child: text,
        builder: (context, child) {
          final sweep = const Interval(
            0,
            _shimmerSweepFraction,
            curve: Curves.easeInOut,
          ).transform(_shimmer.value);
          // Moves the band from fully left of the text to fully right of it.
          final center = -_shimmerBandWidth / 2 +
              sweep * (1 + _shimmerBandWidth);
          double stop(double v) => v.clamp(0.0, 1.0);
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: const [
                AppColors.textPrimary,
                AppColors.primaryOrange,
                AppColors.textPrimary,
              ],
              stops: [
                stop(center - _shimmerBandWidth / 2),
                stop(center),
                stop(center + _shimmerBandWidth / 2),
              ],
            ).createShader(bounds),
            child: child,
          );
        },
      ),
    );
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
                    child: _buildMessage(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

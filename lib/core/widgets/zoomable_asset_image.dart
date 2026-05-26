import 'package:flutter/material.dart';

/// Pinch-to-zoom wrapper for a single asset image.
class ZoomableAssetImage extends StatelessWidget {
  final String assetPath;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final double minScale;
  final double maxScale;

  const ZoomableAssetImage({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.contain,
    this.errorBuilder,
    this.minScale = 1.0,
    this.maxScale = 4.0,
  });

  static const pinchToZoomHint = Text(
    'Pinch to zoom',
    style: TextStyle(
      fontSize: 12,
      color: Color(0xFF8E8E93),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      key: ValueKey(assetPath),
      minScale: minScale,
      maxScale: maxScale,
      panEnabled: true,
      scaleEnabled: true,
      clipBehavior: Clip.hardEdge,
      child: Image.asset(
        assetPath,
        fit: fit,
        errorBuilder: errorBuilder,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Pinch-to-zoom wrapper for a single asset image.
///
/// While zoomed in, one-finger panning is enabled so the user can move
/// around the enlarged image. While at the default scale, one-finger
/// panning is disabled so a horizontal drag falls through to an ancestor
/// (e.g. a [PageView]) instead of being captured here — otherwise pinch-pan
/// and swipe-to-change-page gestures fight each other in the same arena.
class ZoomableAssetImage extends StatefulWidget {
  final String assetPath;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final double minScale;
  final double maxScale;
  final ValueChanged<bool>? onZoomChanged;

  const ZoomableAssetImage({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.contain,
    this.errorBuilder,
    this.minScale = 1.0,
    this.maxScale = 4.0,
    this.onZoomChanged,
  });

  static const pinchToZoomHint = Text(
    'Pinch to zoom',
    style: TextStyle(
      fontSize: 12,
      color: Color(0xFF8E8E93),
    ),
  );

  @override
  State<ZoomableAssetImage> createState() => _ZoomableAssetImageState();
}

class _ZoomableAssetImageState extends State<ZoomableAssetImage> {
  final TransformationController _transformationController =
      TransformationController();
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > widget.minScale + 0.01;
    if (isZoomed != _isZoomed) {
      setState(() => _isZoomed = isZoomed);
      widget.onZoomChanged?.call(isZoomed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      key: ValueKey(widget.assetPath),
      transformationController: _transformationController,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      panEnabled: _isZoomed,
      scaleEnabled: true,
      clipBehavior: Clip.hardEdge,
      child: Image.asset(
        widget.assetPath,
        fit: widget.fit,
        errorBuilder: widget.errorBuilder,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a pantry category icon from either an SVG or raster asset path.
class PantryCategoryIcon extends StatelessWidget {
  final String assetPath;
  final double size;

  const PantryCategoryIcon({
    super.key,
    required this.assetPath,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (assetPath.isEmpty) {
      return Icon(Icons.widgets_outlined, size: size, color: Colors.grey[600]);
    }
    final lower = assetPath.toLowerCase();
    if (lower.endsWith('.svg')) {
      return SvgPicture.asset(assetPath, width: size, height: size);
    }
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

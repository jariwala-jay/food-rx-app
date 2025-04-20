import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onChatTap;
  final VoidCallback onEducationTap;

  const CustomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onHomeTap,
    required this.onChatTap,
    required this.onEducationTap,
  }) : super(key: key);

  /// Builds a navigation item with an icon and a label.
  /// The [scale] parameter adjusts the size dynamically.
  Widget _buildNavItem({
    required String svgPath,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    double scale = 1.0,
  }) {
    const Color activeColor = Color(0xFF181818);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            svgPath,
            width: 28 * scale,
            height: 28 * scale,
            colorFilter: ColorFilter.mode(
              isSelected ? activeColor : Colors.grey,
              BlendMode.srcIn,
            ),
          ),
          SizedBox(height: 4 * scale),
          Text(
            label,
            style: TextStyle(
              fontSize: 12 * scale,
              color: isSelected ? activeColor : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The design uses a 375x77 viewBox.
    return LayoutBuilder(builder: (context, constraints) {
      // Calculate the scale factor based on the actual device width.
      final double scale = constraints.maxWidth / 375.0;
      final double containerHeight = 77 * scale;

      // Define positions relative to the design (scaled dynamically).
      final Offset leftIconCenter = Offset(70 * scale, 45 * scale);
      final Offset rightIconCenter = Offset(305 * scale, 45 * scale);
      final Offset centerButtonCenter = Offset(187.5 * scale, 10 * scale);
      // Chat button size relative to design; adjust if needed.
      final double chatButtonDiameter = 60 * scale;

      return Container(
        width: constraints.maxWidth,
        height: containerHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // SVG background (with the cutout built into it)
            Positioned.fill(
              child: SvgPicture.asset(
                'assets/icons/Subtract.svg', // Ensure this path matches your assets
                fit: BoxFit.fill,
              ),
            ),
            // Left nav item (Home)
            Positioned(
              left: leftIconCenter.dx - (11 * scale) /*half width approx*/,
              top: leftIconCenter.dy -
                  (70 * scale) /
                      2, // estimated widget height: icon (28*scale) + spacing (4*scale) + text (12*scale) = 44*scale
              child: _buildNavItem(
                svgPath: 'assets/icons/home.svg',
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: onHomeTap,
                scale: scale * 0.85,
              ),
            ),
            // Right nav item (Education)
            Positioned(
              left: rightIconCenter.dx - (45 * scale),
              top: rightIconCenter.dy - (70 * scale) / 2,
              child: _buildNavItem(
                svgPath: 'assets/icons/education.svg',
                label: 'Education',
                isSelected: currentIndex == 2,
                onTap: onEducationTap,
                scale: scale * 0.85,
              ),
            ),
            // Center floating chat button positioned inside the SVG cutout
            Positioned(
              left: centerButtonCenter.dx - chatButtonDiameter / 2,
              top: centerButtonCenter.dy - chatButtonDiameter / 2,
              child: GestureDetector(
                onTap: onChatTap,
                child: Container(
                  width: chatButtonDiameter,
                  height: chatButtonDiameter,
                  decoration: const BoxDecoration(
                    color: const Color(0xFFFF6A00),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/icons/chatbot.png',
                      width: 28 * scale,
                      height: 28 * scale,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

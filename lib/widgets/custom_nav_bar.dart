import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomNavBarShape extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    const double cornerRadius = 20;
    final double centerWidth = size.width * 0.25;
    final double centerStartPosition = (size.width - centerWidth) / 2;
    const double centerCurveHeight = 20;

    Path path = Path()
      ..moveTo(cornerRadius, 0)
      ..lineTo(centerStartPosition, 0)
      ..quadraticBezierTo(
        centerStartPosition + centerWidth * 0.2,
        0,
        centerStartPosition + centerWidth * 0.2,
        centerCurveHeight,
      )
      ..quadraticBezierTo(
        centerStartPosition + (centerWidth * 0.5),
        centerCurveHeight * 2.2,
        centerStartPosition + centerWidth * 0.8,
        centerCurveHeight,
      )
      ..quadraticBezierTo(
        centerStartPosition + centerWidth,
        0,
        centerStartPosition + centerWidth,
        0,
      )
      ..lineTo(size.width - cornerRadius, 0)
      ..quadraticBezierTo(
        size.width,
        0,
        size.width,
        cornerRadius,
      )
      ..lineTo(size.width, size.height - cornerRadius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - cornerRadius,
        size.height,
      )
      ..lineTo(cornerRadius, size.height)
      ..quadraticBezierTo(
        0,
        size.height,
        0,
        size.height - cornerRadius,
      )
      ..lineTo(0, cornerRadius)
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

  Widget _buildNavItem({
    required String svgPath,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const Color activeColor = Color(0xFF181818);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            svgPath,
            colorFilter: ColorFilter.mode(
              isSelected ? activeColor : Colors.grey,
              BlendMode.srcIn,
            ),
            width: 28,
            height: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
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
    return Container(
      color: const Color(0xFFF7F7F8),
      child: SafeArea(
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xFFF7F7F8),
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 60,
                  child: CustomPaint(
                    painter: CustomNavBarShape(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: _buildNavItem(
                            svgPath: 'assets/icons/home.svg',
                            label: 'Home',
                            isSelected: currentIndex == 0,
                            onTap: onHomeTap,
                          ),
                        ),
                        const Expanded(
                          child: SizedBox(),
                        ),
                        Expanded(
                          child: _buildNavItem(
                            svgPath: 'assets/icons/education.svg',
                            label: 'Education',
                            isSelected: currentIndex == 2,
                            onTap: onEducationTap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: onChatTap,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6A00),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/icons/chatbot.png',
                          width: 28,
                          height: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

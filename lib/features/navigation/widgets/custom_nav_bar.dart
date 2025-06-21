import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onPantryTap;
  final VoidCallback onRecipeTap;
  final VoidCallback onChatTap;
  final VoidCallback onEducationTap;
  final bool isAddActive;
  final VoidCallback onAddTap;

  const CustomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onHomeTap,
    required this.onPantryTap,
    required this.onRecipeTap,
    required this.onChatTap,
    required this.onEducationTap,
    required this.isAddActive,
    required this.onAddTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Make sure the navigation bar is at the bottom with no margins
    return Container(
      height: 70,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  svgPath: 'assets/icons/home.svg',
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onTap: onHomeTap,
                ),
                _buildNavItem(
                  svgPath: 'assets/icons/pantry.svg',
                  label: 'Pantry',
                  isSelected: currentIndex == 1,
                  onTap: onPantryTap,
                ),
                // Empty space for center button
                const SizedBox(width: 60),
                _buildNavItem(
                  svgPath: 'assets/icons/recipe.svg',
                  label: 'Recipe',
                  isSelected: currentIndex == 2,
                  onTap: onRecipeTap,
                ),
                _buildNavItem(
                  svgPath: 'assets/icons/education.svg',
                  label: 'Education',
                  isSelected: currentIndex == 3,
                  onTap: onEducationTap,
                ),
              ],
            ),
          ),
          // Center floating button with animation
          Positioned(
            top: -20,
            child: GestureDetector(
              onTap: onAddTap,
              child: AnimatedRotation(
                turns: isAddActive ? 0.125 : 0.0, // 45deg = 1/8 turn
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Container(
                  width: 55,
                  height: 55,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6A00),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/add.svg',
                      width: 32,
                      height: 32,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        children: [
          SvgPicture.asset(
            svgPath,
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(
              isSelected ? activeColor : Colors.grey,
              BlendMode.srcIn,
            ),
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
}

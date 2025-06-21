import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ModalActionButton extends StatelessWidget {
  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final bool shouldClose;

  const ModalActionButton({
    Key? key,
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.shouldClose = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: GestureDetector(
        onTap: () {
          if (shouldClose) Navigator.of(context).pop();
          onTap();
        },
        child: Container(
          height: 115,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 45,
                height: 45,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x19FF6A00),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: iconAsset.endsWith('.svg')
                    ? SvgPicture.asset(
                        iconAsset,
                        width: 27,
                        height: 27,
                        fit: BoxFit.contain,
                      )
                    : const Icon(Icons.circle, color: Color(0xFFFF6A00)),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF2C2C2C),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Bricolage Grotesque',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

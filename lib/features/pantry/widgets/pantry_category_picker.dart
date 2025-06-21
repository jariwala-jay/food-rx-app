import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_app/features/pantry/views/pantry_item_picker_page.dart';

class PantryCategoryPicker extends StatelessWidget {
  final String title;
  final List<Map<String, String>> categories;
  final VoidCallback onBack;
  final bool isFoodPantryItem;

  const PantryCategoryPicker({
    Key? key,
    required this.title,
    required this.categories,
    required this.onBack,
    required this.isFoodPantryItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: onBack,
              splashRadius: 20,
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 40), // To balance the back button
          ],
        ),
        const SizedBox(height: 8),
        ...categories.map((cat) => ListTile(
              leading: SvgPicture.asset(cat['icon']!, width: 40, height: 40),
              title: Text(
                cat['title']!,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
              subtitle: cat['subtitle'] != null && cat['subtitle']!.isNotEmpty
                  ? Text(
                      cat['subtitle']!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    )
                  : null,
              trailing:
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PantryItemPickerPage(
                      categoryTitle: cat['title']!,
                      categoryKey: cat['key']!,
                      isFoodPantryItem: isFoodPantryItem,
                    ),
                  ),
                );
              },
            )),
      ],
    );
  }
}

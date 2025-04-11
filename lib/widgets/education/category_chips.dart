import 'package:flutter/material.dart';
import 'package:flutter_app/models/category.dart';

class CategoryChips extends StatelessWidget {
  final List<Category> categories;
  final Function(Category) onCategorySelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: category.isSelected,
                label: Text(category.name),
                onSelected: (_) => onCategorySelected(category),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFFFF6A00),
                labelStyle: TextStyle(
                  color: category.isSelected ? Colors.white : Colors.grey[600],
                  fontSize: 14,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: category.isSelected
                        ? const Color(0xFFFF6A00)
                        : Colors.grey[300]!,
                  ),
                ),
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
  }
}

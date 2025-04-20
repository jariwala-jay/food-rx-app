import 'package:flutter/material.dart';
import '../../models/category.dart';

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
        children: categories.map((category) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onCategorySelected(category),
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: category.isSelected
                      ? const Color(0xFFFF6A00)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: category.isSelected
                        ? const Color(0xFFFF6A00)
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: category.icon != null
                    ? Icon(
                        category.icon,
                        color: category.isSelected
                            ? Colors.white
                            : Colors.grey.shade600,
                        size: 20,
                      )
                    : Text(
                        category.name,
                        style: TextStyle(
                          color: category.isSelected
                              ? Colors.white
                              : Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

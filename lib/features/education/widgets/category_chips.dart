import 'package:flutter/material.dart';
import 'package:flutter_app/features/education/models/category.dart';

class CategoryChips extends StatelessWidget {
  final List<Category> categories;
  final Function(Category) onCategorySelected;
  final VoidCallback onAllSelected;
  final VoidCallback onBookmarksSelected;
  final Category? selectedCategory;
  final bool bookmarksSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.onCategorySelected,
    required this.onAllSelected,
    required this.onBookmarksSelected,
    required this.selectedCategory,
    required this.bookmarksSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          _buildChip(
            context: context,
            label: 'All',
            isSelected: !bookmarksSelected && selectedCategory == null,
            onTap: onAllSelected,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context: context,
            icon: Icons.bookmark_border,
            isSelected: bookmarksSelected,
            onTap: onBookmarksSelected,
          ),
          ...categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildChip(
                context: context,
                label: category.name,
                isSelected: !bookmarksSelected && selectedCategory == category,
                onTap: () => onCategorySelected(category),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    String? label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    const color = Color(0xFFFF6A00); // App's theme color
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: icon != null
            ? Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 20,
              )
            : Text(
                label!,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

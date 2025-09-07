import 'package:flutter/material.dart';

class CategoryFilterChips extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final Function(String?) onCategorySelected;
  final bool isLoading;

  const CategoryFilterChips({
    Key? key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading || categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // All categories chip
          _buildFilterChip(
            label: 'All',
            isSelected: selectedCategory == null,
            onTap: () => onCategorySelected(null),
          ),
          const SizedBox(width: 8),
          // Category chips
          ...categories.map((category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: _formatCategoryName(category),
                  isSelected: selectedCategory == category,
                  onTap: () => onCategorySelected(category),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6A00) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6A00) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatCategoryName(String category) {
    // Convert category keys to display names
    switch (category.toLowerCase()) {
      case 'fresh_fruits':
        return 'Fresh Fruits';
      case 'canned_fruits':
        return 'Canned Fruits';
      case 'fresh_veggies':
        return 'Fresh Veggies';
      case 'canned_veggies':
        return 'Canned Veggies';
      case 'grains':
        return 'Grains';
      case 'protein':
        return 'Protein';
      case 'dairy':
        return 'Dairy';
      case 'seasonings':
        return 'Seasonings';
      case 'fresh_produce':
        return 'Fresh Produce';
      case 'dairy_eggs':
        return 'Dairy & Eggs';
      case 'protein_meat':
        return 'Protein & Meat';
      case 'pantry_staples':
        return 'Pantry Staples';
      case 'frozen_foods':
        return 'Frozen Foods';
      case 'snacks_beverages':
        return 'Snacks & Beverages';
      case 'essentials_condiments':
        return 'Essentials & Condiments';
      case 'miscellaneous':
        return 'Miscellaneous';
      default:
        // Convert snake_case to Title Case
        return category
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }
}


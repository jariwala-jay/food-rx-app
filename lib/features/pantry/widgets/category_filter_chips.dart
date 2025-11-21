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

    // Get text scale factor and clamp it for UI elements that must fit
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);
    
    // Calculate responsive height based on text scaling
    final baseHeight = 40.0;
    final chipHeight = baseHeight * clampedScale.clamp(1.0, 1.1);

    return Container(
      height: chipHeight,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // All categories chip
          _buildFilterChip(
            context: context,
            label: 'All',
            isSelected: selectedCategory == null,
            onTap: () => onCategorySelected(null),
          ),
          SizedBox(width: 8 * clampedScale),
          // Category chips
          ...categories.map((category) => Padding(
                padding: EdgeInsets.only(right: 8 * clampedScale),
                child: _buildFilterChip(
                  context: context,
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
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Get text scale factor and clamp it for UI elements that must fit
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minHeight: 32 * clampedScale,
          maxHeight: 40 * clampedScale,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 16 * clampedScale,
          vertical: 8 * clampedScale,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6A00) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6A00) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontSize: 14 * clampedScale,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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


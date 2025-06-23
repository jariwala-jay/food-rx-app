import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';

class RecipeDetailPage extends StatefulWidget {
  final Recipe recipe;
  final int? targetServings;

  const RecipeDetailPage({
    Key? key,
    required this.recipe,
    this.targetServings,
  }) : super(key: key);

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  late Recipe _adjustedRecipe;

  @override
  void initState() {
    super.initState();
    _adjustedRecipe = _getAdjustedRecipe();
  }

  Recipe _getAdjustedRecipe() {
    final target = widget.targetServings;
    final original = widget.recipe.servings;

    if (target == null || target <= 0 || original <= 0 || target == original) {
      return widget.recipe;
    }

    final ratio = target / original;
    final unitConversionService = UnitConversionService();

    final adjustedIngredients = widget.recipe.extendedIngredients.map((ing) {
      final scaledAmount = ing.amount * ratio;

      // --- NEW: Smart unit optimization ---
      final optimized =
          unitConversionService.optimizeUnits(scaledAmount, ing.unit);
      final newAmount = optimized['amount'] as double;
      final newUnit = optimized['unit'] as String;

      // Format the new amount to a string, handling decimals nicely.
      String amountStr;
      if (newAmount == newAmount.truncateToDouble()) {
        amountStr = newAmount.toInt().toString();
      } else {
        String formatted = newAmount.toStringAsFixed(2);
        if (formatted.endsWith('.00')) {
          amountStr = newAmount.toInt().toString();
        } else if (formatted.endsWith('0')) {
          amountStr = newAmount.toStringAsFixed(1);
        } else {
          amountStr = formatted;
        }
      }

      // Re-create the 'original' string with the new amount and unit.
      final newOriginal = '$amountStr $newUnit ${ing.nameClean}'.trim();

      return ing.copyWith(
        amount: newAmount,
        unit: newUnit, // Update the unit as well
        original: newOriginal,
      );
    }).toList();

    return widget.recipe.copyWith(
      extendedIngredients: adjustedIngredients,
      servings: target,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageWithOverlay(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(context),
                  const SizedBox(height: 16),
                  _buildIngredientTags(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                      'Ingredients for ${_adjustedRecipe.servings} servings'),
                  const SizedBox(height: 8),
                  _buildIngredientsList(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Instructions'),
                  const SizedBox(height: 8),
                  _buildInstructionsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWithOverlay() {
    return Stack(
      children: [
        Image.network(
          _adjustedRecipe.image,
          width: double.infinity,
          height: 250,
          fit: BoxFit.cover,
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_adjustedRecipe.readyInMinutes} Min',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            _adjustedRecipe.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Consumer<RecipeController>(
          builder: (context, controller, child) {
            return IconButton(
              icon: Icon(
                controller.isRecipeSaved(_adjustedRecipe.id)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: const Color(0xFFFF6A00),
                size: 28,
              ),
              onPressed: () {
                if (controller.isRecipeSaved(_adjustedRecipe.id)) {
                  controller.unsaveRecipe(_adjustedRecipe.id);
                } else {
                  controller.saveRecipe(_adjustedRecipe);
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildIngredientTags() {
    return Row(
      children: [
        _buildTag(
          icon: Icons.kitchen,
          label: '+${_adjustedRecipe.usedIngredientCount ?? 0}',
          color: Colors.green,
        ),
        const SizedBox(width: 12),
        _buildTag(
          icon: Icons.shopping_cart,
          label: '+${_adjustedRecipe.missedIngredientCount ?? 0}',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildIngredientsList() {
    if (_adjustedRecipe.extendedIngredients.isEmpty) {
      return const Text('No ingredients listed.');
    }
    final usedIngredientIds =
        _adjustedRecipe.usedIngredients.map((e) => e.id).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _adjustedRecipe.extendedIngredients.map((ingredient) {
        final bool isAvailable = usedIngredientIds.contains(ingredient.id);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Icon(
                  isAvailable
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isAvailable ? Colors.green : Colors.grey[400],
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ingredient.original,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInstructionsList() {
    if (_adjustedRecipe.analyzedInstructions.isEmpty ||
        _adjustedRecipe.analyzedInstructions.first.steps.isEmpty) {
      return const Text('No instructions available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _adjustedRecipe.analyzedInstructions.first.steps.map((step) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6A00),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${step.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    step.step,
                    style: TextStyle(
                        fontSize: 15, height: 1.5, color: Colors.grey[800]),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

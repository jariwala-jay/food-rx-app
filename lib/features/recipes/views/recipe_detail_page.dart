import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/recipe_scaling_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/diet_serving_service.dart';
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/tracking/controller/tracker_provider.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/core/widgets/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

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
  late RecipeScalingService _scalingService;
  late PantryDeductionService _pantryService;
  late DietServingService _dietService;

  bool _isScaling = false;
  bool _isCooking = false;
  bool _showScalingDetails = false;
  Map<String, dynamic>? _scalingResult;

  @override
  void initState() {
    super.initState();
    final conversionService = UnitConversionService();
    final substitutionService = IngredientSubstitutionService(
      conversionService: conversionService,
    );

    _scalingService = RecipeScalingService(
      conversionService: conversionService,
    );
    _pantryService = PantryDeductionService(
      conversionService: conversionService,
      substitutionService: substitutionService,
    );
    _dietService = DietServingService(
      conversionService: conversionService,
    );
    _adjustedRecipe = _getAdjustedRecipe();
  }

  Recipe _getAdjustedRecipe() {
    final target = widget.targetServings;
    final original = widget.recipe.servings;

    if (target == null || target <= 0 || original <= 0 || target == original) {
      return widget.recipe;
    }

    setState(() {
      _isScaling = true;
    });

    try {
      // Convert Recipe to Map for the scaling service
      final recipeMap = widget.recipe.toJson();

      // Use the enhanced RecipeScalingService
      final result = _scalingService.scaleRecipe(
        originalRecipe: recipeMap,
        targetServings: target,
      );

      _scalingResult = result;

      // Convert back to Recipe object
      return Recipe.fromJson(result);
    } catch (e) {
      print('\n❌ Recipe scaling failed: $e');
      setState(() {
        _isScaling = false;
      });

      // Fallback to original recipe if scaling fails
      return widget.recipe;
    }
  }

  Future<void> _cookRecipe() async {
    setState(() {
      _isCooking = true;
    });

    try {
      final pantryController =
          Provider.of<PantryController>(context, listen: false);
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final trackerProvider =
          Provider.of<TrackerProvider>(context, listen: false);

      if (kDebugMode) {
        print('\n🍳 ===== RECIPE DETAIL PAGE COOKING =====');
        print('Recipe: ${_adjustedRecipe.title}');
        print('Recipe servings: ${_adjustedRecipe.servings}');
      }

      // Step 1: Deduct ingredients from pantry
      final scaledIngredients = _adjustedRecipe.extendedIngredients
          .map((ing) => {
                'name': ing.nameClean,
                'amount': ing.amount,
                'unit': ing.unit, // Units are now clean from the source
              })
          .toList();

      if (kDebugMode) {
        print('\n📦 PANTRY DEDUCTION (RECIPE DETAIL PAGE)...');
        print('Current pantry items: ${pantryController.pantryItems.length}');
        print('Current other items: ${pantryController.otherItems.length}');
      }

      final deductionResult = await _pantryService.deductIngredientsFromPantry(
        scaledIngredients: scaledIngredients,
        pantryItems: [
          ...pantryController.pantryItems,
          ...pantryController.otherItems
        ],
      );

      if (kDebugMode) {
        print('\n📦 DEDUCTION RESULT:');
        print(
            'Successful: ${deductionResult.successfulDeductions}/${deductionResult.totalIngredientsProcessed}');
        print('Updated items: ${deductionResult.updatedItems.length}');
        print('Items to remove: ${deductionResult.itemsToRemove.length}');
      }

      // Step 1.5: ACTUALLY PERSIST THE PANTRY CHANGES TO DATABASE
      if (kDebugMode) {
        print('\n💾 PERSISTING PANTRY CHANGES TO DATABASE...');
      }

      // Update quantities for modified items
      for (final updatedItem in deductionResult.updatedItems) {
        if (kDebugMode) {
          print(
              'Updating ${updatedItem.name}: ${updatedItem.quantity} ${updatedItem.unit.name}');
        }
        await pantryController.updateItem(updatedItem);
      }

      // Remove depleted items
      for (final itemId in deductionResult.itemsToRemove) {
        if (kDebugMode) {
          print('Removing item: $itemId');
        }
        // Find the item to determine if it's pantry or other
        final itemToRemove = [
          ...pantryController.pantryItems,
          ...pantryController.otherItems
        ].firstWhere((item) => item.id == itemId);
        await pantryController.removeItem(itemId, itemToRemove.isPantryItem);
      }

      if (kDebugMode) {
        print('✅ Pantry changes persisted to database');
      }

      // Step 2: Add to diet tracking (1 serving per person)
      // ONLY track ingredients that were successfully deducted from pantry
      final user = authController.currentUser;
      final userDietType =
          user?.dietType?.toLowerCase() ?? 'myplate'; // Default to MyPlate

      const servingsPerPerson = 1;

      if (kDebugMode) {
        print('\n🥗 DIET TRACKING...');
        print('User diet type: $userDietType');
        print('Only tracking successfully deducted ingredients:');
      }

      // Create a set of successfully deducted ingredient names for quick lookup
      final successfullyDeductedNames = <String>{};
      for (var updatedItem in deductionResult.updatedItems) {
        // Find matching recipe ingredient names
        for (final ingredient in _adjustedRecipe.extendedIngredients) {
          if (ingredient.nameClean
                  .toLowerCase()
                  .contains(updatedItem.name.toLowerCase()) ||
              updatedItem.name
                  .toLowerCase()
                  .contains(ingredient.nameClean.toLowerCase())) {
            successfullyDeductedNames.add(ingredient.nameClean);
          }
        }
      }

      if (kDebugMode) {
        print(
            'Successfully deducted ingredients: ${successfullyDeductedNames.join(', ')}');
        print(
            'Total ingredients in recipe: ${_adjustedRecipe.extendedIngredients.length}');
        print('Will track: ${successfullyDeductedNames.length} ingredients');
      }

      // Aggregate servings by category to avoid duplicate updates
      final Map<TrackerCategory, double> categoryServings = {};

      // Use the clean ingredient data directly from the recipe
      // BUT only track ingredients that were successfully deducted
      for (final ingredient in _adjustedRecipe.extendedIngredients) {
        // Skip ingredients that were NOT successfully deducted from pantry
        if (!successfullyDeductedNames.contains(ingredient.nameClean)) {
          if (kDebugMode) {
            print(
                '  ⏭️ Skipping ${ingredient.nameClean} (not deducted from pantry)');
          }
          continue;
        }

        if (kDebugMode) {
          print('  ✅ Tracking ${ingredient.nameClean} (successfully deducted)');
        }
        final categories = _dietService.getCategoriesForIngredient(
            ingredient.nameClean,
            dietType: userDietType);

        for (final category in categories) {
          double dietServings = 0.0;

          // Skip any remaining malformed units (should be very rare now)
          if (ingredient.unit.toLowerCase() == 'servings' ||
              ingredient.unit.toLowerCase() == 'serving') {
            continue;
          }

          // Calculate servings for the user's selected diet only
          // This is the amount per person (total recipe amount divided by servings)
          final perPersonAmount = ingredient.amount / _adjustedRecipe.servings;

          dietServings = _dietService.getServingsForTracker(
            ingredientName: ingredient.nameClean,
            amount: perPersonAmount * servingsPerPerson,
            unit: ingredient.unit,
            category: category,
            dietType: userDietType,
          );

          if (dietServings > 0) {
            // Round to 2 decimal places and aggregate
            final roundedServings =
                double.parse(dietServings.toStringAsFixed(2));
            categoryServings[category] =
                (categoryServings[category] ?? 0.0) + roundedServings;
          }
        }
      }

      // Add sodium tracking from nutrition data (DASH diet specific)
      if (userDietType == 'dash' && _adjustedRecipe.nutrition != null) {
        final sodiumNutrient = _adjustedRecipe.nutrition!.nutrients
            .where((n) => n.name.toLowerCase() == 'sodium')
            .firstOrNull;

        if (sodiumNutrient != null) {
          // Convert sodium amount per serving to mg if needed
          // The nutrition data is typically per serving, so we multiply by servingsPerPerson
          double sodiumMg = sodiumNutrient.amount * servingsPerPerson;

          // Convert to mg if in different units
          if (sodiumNutrient.unit.toLowerCase() == 'g') {
            sodiumMg *= 1000; // Convert grams to mg
          } else if (sodiumNutrient.unit.toLowerCase() == 'mcg' ||
              sodiumNutrient.unit.toLowerCase() == 'μg') {
            sodiumMg /= 1000; // Convert micrograms to mg
          }

          if (sodiumMg > 0) {
            final roundedSodium = double.parse(sodiumMg.toStringAsFixed(2));
            categoryServings[TrackerCategory.sodium] =
                (categoryServings[TrackerCategory.sodium] ?? 0.0) +
                    roundedSodium;
          }
        }
      }

      // Update tracker for each category
      for (final entry in categoryServings.entries) {
        final category = entry.key;
        final servings = entry.value;

        // Find the matching tracker and update it
        final matchingTracker =
            trackerProvider.findTrackerByCategory(category, userDietType);
        if (matchingTracker != null) {
          await trackerProvider.incrementTracker(matchingTracker.id, servings);
        }
      }

      if (kDebugMode) {
        print('\n✅ RECIPE DETAIL PAGE COOKING COMPLETE');
        print(
            '   Pantry changes: ${deductionResult.updatedItems.length} updated, ${deductionResult.itemsToRemove.length} removed');
        print(
            '   Diet tracking: ${categoryServings.length} categories updated');
        print('===== RECIPE DETAIL PAGE COOKING COMPLETE =====\n');
      }

      // Step 3: Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recipe cooked! Ingredients deducted from pantry (${deductionResult.successfulDeductions}/${deductionResult.totalIngredientsProcessed} successful) and added to diet tracking.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Navigate back to home
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error cooking recipe: $e');
      if (kDebugMode) {
        print('\n❌ RECIPE DETAIL PAGE COOKING FAILED: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cooking recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isCooking = false;
      });
    }
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
                  const SizedBox(height: 16),
                  _buildCookButton(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                      'Ingredients for ${_adjustedRecipe.servings} servings'),
                  const SizedBox(height: 8),
                  if (_scalingResult != null &&
                      widget.targetServings != widget.recipe.servings &&
                      dotenv.env['SHOW_SCALING_CONVERSION'] == 'true')
                    _buildScalingDetailsSection(),
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

  Widget _buildCookButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCooking ? null : _cookRecipe,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6A00),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isCooking
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Cooking...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Cook This Recipe',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildImageWithOverlay() {
    return Stack(
      children: [
        RecipeImage(
          imageUrl: _adjustedRecipe.image,
          width: double.infinity,
          height: 250,
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _adjustedRecipe.title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (widget.targetServings != null &&
                  widget.targetServings != widget.recipe.servings)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Scaled from ${widget.recipe.servings} to ${widget.targetServings} servings',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
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
        color: color.withValues(alpha: 0.1),
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

  Widget _buildScalingDetailsSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _showScalingDetails = !_showScalingDetails;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scaling Details (${widget.recipe.servings} → ${widget.targetServings} servings)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Icon(
                  _showScalingDetails ? Icons.expand_less : Icons.expand_more,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ),
        if (_showScalingDetails) _buildScalingComparison(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildScalingComparison() {
    if (_scalingResult == null) return const SizedBox.shrink();

    final metadata = _scalingResult!['scalingMetadata'];
    final scaleFactor = widget.targetServings! / widget.recipe.servings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scaling metadata
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Scale Factor',
                  '${scaleFactor.toStringAsFixed(2)}x',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  'Confidence',
                  '${(metadata['overallConfidence']).toStringAsFixed(0)}%',
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Ingredient comparison
          const Text(
            'Ingredient Conversions:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          ...widget.recipe.extendedIngredients.asMap().entries.map((entry) {
            final index = entry.key;
            final original = entry.value;
            final scaled = _adjustedRecipe.extendedIngredients[index];
            final expectedAmount = original.amount * scaleFactor;
            final wasOptimized =
                scaled.amount != expectedAmount || scaled.unit != original.unit;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: wasOptimized
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: wasOptimized
                      ? Colors.orange.withValues(alpha: 0.3)
                      : Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    original.nameClean,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${_formatDisplayAmount(original.amount)} ${original.unit}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatDisplayAmount(scaled.amount)} ${scaled.unit}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (wasOptimized) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 14,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Optimized from ${expectedAmount.toStringAsFixed(2)} ${original.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 12),

          // Statistics summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scaling Statistics:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildStatRow(
                    'Total Ingredients', '${metadata['totalIngredients']}'),
                _buildStatRow('Successful Conversions',
                    '${metadata['successfulConversions']}'),
                _buildStatRow(
                    'Unit Optimizations', '${metadata['unitOptimizations']}'),
                _buildStatRow('Seasoning Adjustments',
                    '${metadata['seasoningAdjustments']}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
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

        // Build the display text with scaled amounts
        String displayText = _buildScaledIngredientText(ingredient);

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
                  displayText,
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

  String _formatDisplayAmount(double amount) {
    // Handle whole numbers
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }

    // Handle common fractions with readable display
    const tolerance = 0.01;

    // Check for halves
    if ((amount - 0.5).abs() < tolerance) return '1/2';
    if ((amount - 1.5).abs() < tolerance) return '1 1/2';
    if ((amount - 2.5).abs() < tolerance) return '2 1/2';
    if ((amount - 3.5).abs() < tolerance) return '3 1/2';

    // Check for thirds
    if ((amount - 1 / 3).abs() < tolerance) return '1/3';
    if ((amount - 2 / 3).abs() < tolerance) return '2/3';
    if ((amount - 1.33).abs() < tolerance) return '1 1/3';
    if ((amount - 1.67).abs() < tolerance) return '1 2/3';
    if ((amount - 2.33).abs() < tolerance) return '2 1/3';
    if ((amount - 2.67).abs() < tolerance) return '2 2/3';

    // Check for quarters
    if ((amount - 0.25).abs() < tolerance) return '1/4';
    if ((amount - 0.75).abs() < tolerance) return '3/4';
    if ((amount - 1.25).abs() < tolerance) return '1 1/4';
    if ((amount - 1.75).abs() < tolerance) return '1 3/4';
    if ((amount - 2.25).abs() < tolerance) return '2 1/4';
    if ((amount - 2.75).abs() < tolerance) return '2 3/4';
    if ((amount - 3.25).abs() < tolerance) return '3 1/4';
    if ((amount - 3.75).abs() < tolerance) return '3 3/4';

    // Check for eighths
    if ((amount - 0.125).abs() < tolerance) return '1/8';
    if ((amount - 0.375).abs() < tolerance) return '3/8';
    if ((amount - 0.625).abs() < tolerance) return '5/8';
    if ((amount - 0.875).abs() < tolerance) return '7/8';

    // For other amounts, use reasonable precision
    if (amount < 1) {
      return amount.toStringAsFixed(2);
    } else if (amount < 10) {
      return amount.toStringAsFixed(1);
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  Map<String, dynamic> _optimizeUnits(double amount, String unit) {
    // Handle count-based ingredients that shouldn't be fractional
    final countBasedUnits = ['', 'whole', 'piece', 'pieces', 'item', 'items'];
    if (countBasedUnits.contains(unit.toLowerCase())) {
      // Smart rounding for count-based items to nearest practical fraction
      if (amount <= 0.25) {
        return {'amount': 0.25, 'unit': unit}; // 1/4
      } else if (amount <= 0.375) {
        return {'amount': 0.5, 'unit': unit}; // 1/2
      } else if (amount <= 0.625) {
        return {'amount': 0.5, 'unit': unit}; // 1/2
      } else if (amount <= 0.875) {
        return {'amount': 0.75, 'unit': unit}; // 3/4
      } else if (amount < 1.25) {
        return {'amount': 1.0, 'unit': unit}; // 1
      } else if (amount < 1.75) {
        return {'amount': 1.5, 'unit': unit}; // 1 1/2
      } else if (amount < 2.25) {
        return {'amount': 2.0, 'unit': unit}; // 2
      } else {
        // For larger amounts, round to nearest half
        return {'amount': (amount * 2).round() / 2, 'unit': unit};
      }
    }

    // Convert small tablespoon amounts to teaspoons
    if ((unit == 'tablespoon' || unit == 'tablespoons' || unit == 'tbsp') &&
        amount < 1) {
      final tspAmount = amount * 3;
      return {
        'amount': tspAmount,
        'unit': tspAmount == 1 ? 'teaspoon' : 'teaspoons'
      };
    }

    // Convert large teaspoon amounts to tablespoons
    if ((unit == 'teaspoon' || unit == 'teaspoons' || unit == 'tsp') &&
        amount >= 3) {
      final tbspAmount = amount / 3;
      return {
        'amount': tbspAmount,
        'unit': tbspAmount == 1 ? 'tablespoon' : 'tablespoons'
      };
    }

    // Convert large tablespoon amounts to cups
    if ((unit == 'tablespoon' || unit == 'tablespoons' || unit == 'tbsp') &&
        amount >= 16) {
      final cupAmount = amount / 16;
      return {'amount': cupAmount, 'unit': cupAmount == 1 ? 'cup' : 'cups'};
    }

    // Convert small cup amounts to tablespoons for better readability
    if ((unit == 'cup' || unit == 'cups') && amount < 0.25) {
      final tbspAmount = amount * 16;
      return {
        'amount': tbspAmount,
        'unit': tbspAmount == 1 ? 'tablespoon' : 'tablespoons'
      };
    }

    // Convert large ounce amounts to pounds
    if ((unit == 'ounce' || unit == 'ounces' || unit == 'oz') && amount >= 16) {
      final lbAmount = amount / 16;
      return {'amount': lbAmount, 'unit': lbAmount == 1 ? 'pound' : 'pounds'};
    }

    // Convert small pound amounts to ounces
    if ((unit == 'pound' ||
            unit == 'pounds' ||
            unit == 'lb' ||
            unit == 'lbs') &&
        amount < 0.5) {
      final ozAmount = amount * 16;
      return {'amount': ozAmount, 'unit': ozAmount == 1 ? 'ounce' : 'ounces'};
    }

    // Convert large gram amounts to kilograms
    if ((unit == 'gram' || unit == 'grams' || unit == 'g') && amount >= 1000) {
      final kgAmount = amount / 1000;
      return {
        'amount': kgAmount,
        'unit': kgAmount == 1 ? 'kilogram' : 'kilograms'
      };
    }

    // Convert large milliliter amounts to liters
    if ((unit == 'milliliter' || unit == 'milliliters' || unit == 'ml') &&
        amount >= 1000) {
      final lAmount = amount / 1000;
      return {'amount': lAmount, 'unit': lAmount == 1 ? 'liter' : 'liters'};
    }

    // Return original if no optimization needed
    return {'amount': amount, 'unit': unit};
  }

  String _buildScaledIngredientText(dynamic ingredient) {
    var amount = ingredient.amount;
    var unit = ingredient.unit ?? '';
    final nameClean = ingredient.nameClean ?? ingredient.name ?? '';

    // Apply intelligent unit optimization for better readability
    final optimizedMeasurement = _optimizeUnits(amount, unit);
    amount = optimizedMeasurement['amount'];
    unit = optimizedMeasurement['unit'];

    // Get any additional descriptors from the original text
    String originalText = ingredient.original ?? '';

    // Extract descriptors (text in parentheses, adjectives, etc.)
    String descriptors = '';
    if (originalText.isNotEmpty) {
      // Look for parentheses content
      final parenRegex = RegExp(r'\([^)]*\)');
      final parenMatches = parenRegex.allMatches(originalText);
      for (final match in parenMatches) {
        descriptors += ' ${match.group(0)}';
      }

      // Look for common descriptors before the ingredient name
      final words = originalText.toLowerCase().split(' ');
      final descriptorWords = [
        'fresh',
        'dried',
        'ground',
        'whole',
        'chopped',
        'diced',
        'sliced',
        'grated',
        'shredded',
        'minced',
        'large',
        'small',
        'medium',
        'organic',
        'free-range',
        'lean'
      ];
      for (final word in words) {
        if (descriptorWords.contains(word) &&
            !descriptors.toLowerCase().contains(word)) {
          descriptors = ' $word$descriptors';
        }
      }
    }

    // Build the display text
    String formattedAmount = _formatDisplayAmount(amount);

    if (unit.isEmpty) {
      return '$formattedAmount $nameClean$descriptors';
    } else {
      // Handle unit pluralization
      String displayUnit = unit;
      if (amount != 1.0) {
        // Simple pluralization rules
        if (unit == 'cup' && amount != 1.0) {
          displayUnit = 'cups';
        } else if (unit == 'tablespoon' && amount != 1.0)
          displayUnit = 'tablespoons';
        else if (unit == 'teaspoon' && amount != 1.0)
          displayUnit = 'teaspoons';
        else if (unit == 'ounce' && amount != 1.0)
          displayUnit = 'ounces';
        else if (unit == 'pound' && amount != 1.0)
          displayUnit = 'pounds';
        else if (unit == 'gram' && amount != 1.0)
          displayUnit = 'grams';
        else if (unit == 'kilogram' && amount != 1.0)
          displayUnit = 'kilograms';
        else if (unit == 'liter' && amount != 1.0)
          displayUnit = 'liters';
        else if (unit == 'milliliter' && amount != 1.0)
          displayUnit = 'milliliters';
        else if (unit == 'serving' && amount != 1.0)
          displayUnit = 'servings';
        else if (unit == 'clove' && amount != 1.0)
          displayUnit = 'cloves';
        else if (unit == 'sprig' && amount != 1.0)
          displayUnit = 'sprigs';
        else if (unit == 'slice' && amount != 1.0)
          displayUnit = 'slices';
        else if (unit == 'piece' && amount != 1.0)
          displayUnit = 'pieces';
        else if (unit == 'packet' && amount != 1.0)
          displayUnit = 'packets';
        // Add abbreviated forms
        else if (unit == 'tsp' && amount != 1.0)
          displayUnit = 'tsp';
        else if (unit == 'tbsp' && amount != 1.0)
          displayUnit = 'tbsp';
        else if (unit == 'oz' && amount != 1.0)
          displayUnit = 'oz';
        else if (unit == 'lb' && amount != 1.0)
          displayUnit = 'lbs';
        else if (unit == 'g' && amount != 1.0)
          displayUnit = 'g';
        else if (unit == 'kg' && amount != 1.0)
          displayUnit = 'kg';
        else if (unit == 'ml' && amount != 1.0)
          displayUnit = 'ml';
        else if (unit == 'l' && amount != 1.0) displayUnit = 'l';
      }

      return '$formattedAmount $displayUnit $nameClean$descriptors';
    }
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

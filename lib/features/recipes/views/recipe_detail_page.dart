import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/recipe_scaling_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/diet_serving_service.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/tracking/controller/tracker_provider.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/features/tracking/notifications/goal_limit_notification_service.dart';
import 'package:flutter_app/features/recipes/utils/recipe_ingredient_pantry_counts.dart';
import 'package:flutter_app/features/recipes/widgets/servings_consumed_modal.dart';
import 'package:flutter_app/core/widgets/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_app/core/utils/user_facing_errors.dart';
import 'package:flutter_app/core/utils/kitchen_quantity_formatter.dart';
import 'package:provider/provider.dart';

class RecipeDetailPage extends StatefulWidget {
  final Recipe recipe;
  final int? targetServings;
  /// When true (e.g. opened from Prepared recipes), hide "I Cooked This" and show only back.
  final bool fromPreparedRecipes;
  /// Optional leftover servings when opened from Prepared recipes.
  final double? leftoverServings;

  const RecipeDetailPage({
    Key? key,
    required this.recipe,
    this.targetServings,
    this.fromPreparedRecipes = false,
    this.leftoverServings,
  }) : super(key: key);

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  static const KitchenQuantityFormatter _kitchenFormatter =
      KitchenQuantityFormatter();

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

      if (kDebugMode) {
        _logScaledSpringOnionIngredient(result);
      }

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

  /// Shows the servings consumed modal; on confirm, runs cook logic with scaled values.
  Future<void> _showServingsModalAndCook() async {
    final recipeServings = _adjustedRecipe.servings;
    if (recipeServings <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid recipe servings'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ServingsConsumedModal(
        recipeServings: recipeServings,
      ),
    );

    if (result == null || !mounted) return;

    await _performCookRecipe(result);
  }

  Future<void> _performCookRecipe(double servingsConsumed) async {
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

      final recipeServings = _adjustedRecipe.servings.toDouble();
      final consumedFraction = (recipeServings > 0)
          ? (servingsConsumed / recipeServings).clamp(0.0, 1.0)
          : 1.0;

      if (kDebugMode) {
        print('\n🍳 ===== RECIPE DETAIL PAGE COOKING =====');
        print('Recipe: ${_adjustedRecipe.title}');
        print('Recipe servings: $recipeServings, consumed: $servingsConsumed');
        print('Consumed fraction: $consumedFraction');
      }

      // Step 1: Deduct ingredients from pantry (scaled by consumed fraction)
      final scaledIngredients = _adjustedRecipe.extendedIngredients
          .map((ing) => {
                'name': ing.nameClean,
                'amount': ing.amount * consumedFraction,
                'unit': ing.unit,
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

      // Step 2: Add to diet tracking (scaled by servings consumed)
      final user = authController.currentUser;
      final userDietType =
          user?.dietType?.toLowerCase() ?? 'myplate'; // Default to MyPlate

      if (kDebugMode) {
        print('\n🥗 DIET TRACKING...');
        print('User diet type: $userDietType, servings consumed: $servingsConsumed');
        print('Tracking recipe ingredients for consumed portions:');
      }

      // Aggregate servings by category to avoid duplicate updates
      final Map<TrackerCategory, double> categoryServings = {};

      // Use the clean ingredient data directly from the recipe
      // Track ALL ingredients regardless of pantry availability
      for (final ingredient in _adjustedRecipe.extendedIngredients) {
        if (kDebugMode) {
          print('  ✅ Tracking ${ingredient.nameClean} (recipe ingredient)');
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

          // Calculate servings: amount per serving * servings consumed
          final perPersonAmount = ingredient.amount / _adjustedRecipe.servings;

          dietServings = _dietService.getServingsForTracker(
            ingredientName: ingredient.nameClean,
            amount: perPersonAmount * servingsConsumed,
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
          // Convert sodium amount per serving to mg (scale by servings consumed)
          double sodiumMg = sodiumNutrient.amount * servingsConsumed;

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
      final goalLimitSnapshot = GoalLimitNotificationService.instance.snapshot(
        [...trackerProvider.dailyTrackers, ...trackerProvider.weeklyTrackers],
      );
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
      GoalLimitNotificationService.instance.checkAndNotify(
        before: goalLimitSnapshot,
        trackers: [...trackerProvider.dailyTrackers, ...trackerProvider.weeklyTrackers],
      );

      if (kDebugMode) {
        print('\n✅ RECIPE DETAIL PAGE COOKING COMPLETE');
        print(
            '   Pantry changes: ${deductionResult.updatedItems.length} updated, ${deductionResult.itemsToRemove.length} removed');
        print(
            '   Diet tracking: ${categoryServings.length} categories updated (ALL recipe ingredients tracked)');
        print('===== RECIPE DETAIL PAGE COOKING COMPLETE =====\n');
      }

      // Step 3: Show success message
      if (mounted) {
        final servingText = servingsConsumed == servingsConsumed.truncateToDouble()
            ? servingsConsumed.toInt().toString()
            : servingsConsumed.toStringAsFixed(2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged $servingText serving(s)! Pantry: ${deductionResult.successfulDeductions}/${deductionResult.totalIngredientsProcessed} deducted. Diet tracking updated.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Step 4: Store leftover in Prepared recipes (for "Prepared recipes" list)
      final leftoverServings =
          _adjustedRecipe.servings.toDouble() - servingsConsumed;
      if (leftoverServings > 0 && mounted) {
        try {
          final recipeController =
              Provider.of<RecipeController>(context, listen: false);
          await recipeController.logPreparedFromCook(
            recipe: _adjustedRecipe,
            totalServings: _adjustedRecipe.servings.toDouble(),
            consumedServings: servingsConsumed,
          );
        } catch (e) {
          debugPrint('Failed to save prepared recipe leftover: $e');
        }
      }

      // Navigate back to recipe tab
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
            content: Text(userFacingErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCooking = false;
        });
      }
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
      bottomNavigationBar: widget.fromPreparedRecipes
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildCookButton(),
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
                  Consumer<PantryController>(
                    builder: (context, pantryController, _) {
                      final pantry = [
                        ...pantryController.pantryItems,
                        ...pantryController.otherItems,
                      ];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIngredientTags(pantry),
                          const SizedBox(height: 24),
                          _buildSectionTitle(
                              'Ingredients for ${_adjustedRecipe.servings} servings'),
                          if (_adjustedRecipe.optionalIngredientLineCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${_adjustedRecipe.requiredIngredientLineCount} required · '
                                '${_adjustedRecipe.optionalIngredientLineCount} optional',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (_scalingResult != null &&
                              widget.targetServings != widget.recipe.servings &&
                              dotenv.env['SHOW_SCALING_CONVERSION'] ==
                                  'true')
                            _buildScalingDetailsSection(),
                          _buildIngredientsList(pantry),
                        ],
                      );
                    },
                  ),
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
        onPressed: _isCooking ? null : _showServingsModalAndCook,
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
                    'Processing...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'I Cooked This',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.restaurant, size: 20),
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
          imageUrlCandidates: _adjustedRecipe.imageUrlCandidates,
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
              if (widget.fromPreparedRecipes &&
                  (widget.leftoverServings ?? 0) > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${(widget.leftoverServings! == widget.leftoverServings!.truncateToDouble()) ? widget.leftoverServings!.toInt().toString() : widget.leftoverServings!.toStringAsFixed(2)} serving${widget.leftoverServings == 1 ? '' : 's'} left',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFF6A00),
                  ),
                ),
              ],
            ],
          ),
        ),
        Consumer<RecipeController>(
          builder: (context, controller, child) {
            return IconButton(
              icon: Icon(
                controller.isRecipeSaved(_adjustedRecipe.id)
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
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

  RecipeIngredientPantryCounts get _pantryCounts =>
      RecipeIngredientPantryCounts(_pantryService);

  bool _ingredientInPantry(RecipeIngredient ingredient, List<PantryItem> pantry) {
    return _pantryCounts.isInPantry(ingredient, pantry);
  }

  Widget _buildIngredientTags(List<PantryItem> pantry) {
    return Row(
      children: [
        _buildTag(
          icon: Icons.kitchen,
          label: '+${_pantryCounts.inPantryCount(_adjustedRecipe, pantry)}',
          color: Colors.green,
        ),
        const SizedBox(width: 12),
        _buildTag(
          icon: Icons.shopping_cart,
          label:
              '+${_pantryCounts.requiredMissingCount(_adjustedRecipe, pantry)}',
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
            final wasScaled = scaled.amount != expectedAmount ||
                scaled.unit != original.unit;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: wasScaled
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: wasScaled
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
                        _kitchenFormatter.formatIngredientLine(
                          amount: original.amount,
                          unit: original.unit,
                          ingredientName: original.nameClean,
                        ),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        _kitchenFormatter.formatIngredientLine(
                          amount: scaled.amount,
                          unit: scaled.unit,
                          ingredientName: scaled.nameClean,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (wasScaled) ...[
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
                          'Exact scaled amount: ${expectedAmount.toStringAsFixed(4)} ${original.unit}',
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

  Widget _buildIngredientsList(List<PantryItem> pantry) {
    final ingredients = RecipeIngredient.mergeDuplicateLines(
      _adjustedRecipe.extendedIngredients,
    );
    if (ingredients.isEmpty) {
      return const Text('No ingredients listed.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ingredients.map((ingredient) {
        final bool isAvailable = _ingredientInPantry(ingredient, pantry);

        final isOptional = ingredient.isOptionalIngredient;
        final displayText = ingredient.formatDisplayLine(
          _buildScaledIngredientText(ingredient),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Icon(
                  isOptional
                      ? Icons.remove_circle_outline
                      : (isAvailable
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked),
                  color: isOptional
                      ? Colors.grey[400]
                      : (isAvailable ? Colors.green : Colors.grey[400]),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 14,
                    color: isOptional ? Colors.grey[600] : Colors.grey[800],
                    height: 1.4,
                    fontStyle:
                        isOptional ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _buildScaledIngredientText(dynamic ingredient) {
    final amount = ingredient.amount;
    final rawUnit = (ingredient.unit ?? '').toString();
    final rawName = (ingredient.name ?? '').toString();
    final rawNameClean = (ingredient.nameClean ?? '').toString();
    final rawOriginal = (ingredient.original ?? '').toString();
    final rawOriginalName = (ingredient.originalName ?? '').toString();
    final traceFormat = kDebugMode &&
        _shouldTraceIngredientFormat(rawNameClean, rawName);

    if (traceFormat) {
      debugPrint('''
[Ingredient BEFORE FORMAT]
name=$rawName
nameClean=$rawNameClean
originalName=$rawOriginalName
original=$rawOriginal
unit(raw)=$rawUnit
amount=$amount
''');
    }

    final nameClean = RecipeIngredient.resolveDisplayName(
      rawNameClean,
      rawName,
    );
    final unit = RecipeIngredient.sanitizeUnit(
      rawUnit,
      nameClean,
    );

    // Extract prep descriptors and parenthetical notes from the original line.
    String originalText = rawOriginal;
    String prepDescriptors = '';
    String parentheticalNotes = '';

    if (originalText.isNotEmpty) {
      final parenRegex = RegExp(r'\([^)]*\)');
      final parenMatches = parenRegex.allMatches(originalText);
      for (final match in parenMatches) {
        parentheticalNotes += ' ${match.group(0)}';
      }

      final words = originalText.toLowerCase().split(' ');
      const descriptorWords = [
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
            !prepDescriptors.toLowerCase().contains(word) &&
            !nameClean.toLowerCase().contains(word)) {
          prepDescriptors = ' $word$prepDescriptors';
        }
      }
    }

    final displayName = RecipeIngredient.composeIngredientDisplayName(
      nameClean,
      prepDescriptors,
    );

    if (traceFormat) {
      debugPrint('''
[Ingredient FORMAT INPUT]
unit(sanitized)=$unit
displayName=$displayName
prepDescriptors=$prepDescriptors
parentheticalNotes=$parentheticalNotes
''');
    }

    final formatted = _kitchenFormatter.formatIngredientLineWithPath(
      amount: amount,
      unit: unit,
      ingredientName: displayName,
      descriptors: parentheticalNotes,
    );

    final displayText = RecipeIngredient.dedupeConsecutiveWords(formatted.display);

    if (traceFormat) {
      debugPrint('''
[Ingredient AFTER FORMAT]
path=${formatted.path.label}
formatterOutput=${formatted.display}
output=$displayText
''');
    }

    return displayText;
  }

  bool _shouldTraceIngredientFormat(String nameClean, String? rawName) {
    final lower = '${nameClean.toLowerCase()} ${(rawName ?? '').toLowerCase()}';
    return lower.contains('spring onion') ||
        lower.contains('scallion') ||
        lower.contains('green onion') ||
        lower.contains('juice') ||
        lower.contains('lemon') ||
        lower.contains('lime');
  }

  void _logScaledSpringOnionIngredient(Map<String, dynamic> scaledRecipe) {
    final ingredients = scaledRecipe['extendedIngredients'] as List<dynamic>?;
    if (ingredients == null) return;

    for (final raw in ingredients) {
      final ingredient = raw as Map<String, dynamic>;
      final name = (ingredient['name'] ?? '').toString();
      final nameClean = (ingredient['nameClean'] ?? '').toString();
      if (!_shouldTraceIngredientFormat(nameClean, name)) continue;

      final scalingMetadata =
          ingredient['scalingMetadata'] as Map<String, dynamic>?;

      debugPrint('''
[Ingredient AFTER SCALING]
name=$name
nameClean=$nameClean
original=${ingredient['original']}
originalAmount=${scalingMetadata?['originalAmount']}
originalUnit=${scalingMetadata?['originalUnit']}
scaleFactor=${scalingMetadata?['scaleFactor']}
unit=${ingredient['unit']}
amount=${ingredient['amount']}
servings=${scaledRecipe['servings']}
''');
    }
  }

  Widget _buildInstructionsUnavailable() {
    final source = _adjustedRecipe.sourceUrl.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step-by-step instructions are not available in the app for this recipe.',
          style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800]),
        ),
        if (source.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'View the original recipe:',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          SelectableText(
            source,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFFF6A00),
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInstructionsList() {
    if (_adjustedRecipe.analyzedInstructions.isEmpty) {
      return _buildInstructionsUnavailable();
    }

    final steps = _adjustedRecipe.analyzedInstructions.first.cookingSteps;
    if (steps.isEmpty) {
      return _buildInstructionsUnavailable();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.asMap().entries.map((entry) {
        final displayNumber = entry.key + 1;
        final step = entry.value;
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
                    '$displayNumber',
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

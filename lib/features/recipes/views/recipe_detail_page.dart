import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';

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
  bool _isCooking = false;

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
    final adjustedIngredients = widget.recipe.extendedIngredients.map((ing) {
      final newAmount = ing.amount * ratio;

      // Format the amount to a string, handling decimals nicely.
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

      // Re-create the 'original' string with the new amount.
      final newOriginal =
          '$amountStr ${ing.unit} ${ing.nameClean ?? ing.name}'.trim();

      return ing.copyWith(
        amount: newAmount,
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
      body: Stack(
        children: [
          // Main content with bottom padding for sticky button
          SingleChildScrollView(
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
                      const SizedBox(height: 100), // Space for sticky button
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Sticky Cook Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStickyButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Consumer<RecipeController>(
          builder: (context, controller, child) {
            return SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isCooking || controller.isLoading
                    ? null
                    : () => _showCookingDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 2,
                ),
                child: _isCooking || controller.isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Cooking...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCookingDialog() {
    if (_adjustedRecipe.servings <= 1) {
      // Single serving - cook directly (deduct full recipe, track 1 serving)
      _cookRecipe(1, _adjustedRecipe.servings);
      return;
    }

    // Multiple servings - show distribution dialog
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildServingDistributionDialog(),
    );
  }

  Widget _buildServingDistributionDialog() {
    int servingsForUser =
        1; // Servings that will be tracked for the user's diet
    int servingsForFamily =
        0; // Servings for family members (tracked ingredients but not diet)
    int servingsForLater =
        _adjustedRecipe.servings - 1; // Leftovers (not tracked at all)

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Serving distribution
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Servings for user (tracked in diet)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F8FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE3F2FD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person,
                                    color: Colors.blue[600], size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Eating now (tracks my diet)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: servingsForUser > 0
                                      ? () {
                                          setModalState(() {
                                            servingsForUser--;
                                            servingsForLater++;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Expanded(
                                  child: Text(
                                    '$servingsForUser ${servingsForUser == 1 ? 'serving' : 'servings'}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: servingsForLater > 0
                                      ? () {
                                          setModalState(() {
                                            servingsForUser++;
                                            servingsForLater--;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Servings for family (ingredients tracked but not diet)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FFF0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8F5E8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.family_restroom,
                                    color: Colors.green[600], size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Family eating now (no diet tracking)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Already deducted from pantry, but won\'t track your diet',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: servingsForFamily > 0
                                      ? () {
                                          setModalState(() {
                                            servingsForFamily--;
                                            servingsForLater++;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Expanded(
                                  child: Text(
                                    '$servingsForFamily ${servingsForFamily == 1 ? 'serving' : 'servings'}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: servingsForLater > 0
                                      ? () {
                                          setModalState(() {
                                            servingsForFamily++;
                                            servingsForLater--;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Servings for later (leftovers)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE0B2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.kitchen,
                                    color: Colors.orange[600], size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Leftovers (track later)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$servingsForLater ${servingsForLater == 1 ? 'serving' : 'servings'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (servingsForLater > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Already deducted from pantry, track manually when consumed',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                // Always deduct the full recipe from pantry
                                // Only track the user's consumed servings for diet
                                _cookRecipe(
                                    servingsForUser, _adjustedRecipe.servings);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6A00),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                'Cook Recipe',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cookRecipe(
      int servingsToTrack, int totalServingsToDeduct) async {
    setState(() {
      _isCooking = true;
    });

    try {
      final controller = Provider.of<RecipeController>(context, listen: false);

      // Show loading message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Cooking recipe and updating trackers...'),
              ],
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Cook the recipe with the specified servings
      await controller.cookRecipe(_adjustedRecipe,
          servingsConsumed: servingsToTrack,
          totalServingsToDeduct: totalServingsToDeduct);

      if (mounted) {
        if (controller.error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recipe cooked successfully!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deducted all $totalServingsToDeduct ${totalServingsToDeduct == 1 ? 'serving' : 'servings'} from pantry',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Tracked $servingsToTrack ${servingsToTrack == 1 ? 'serving' : 'servings'} for your diet goals',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (totalServingsToDeduct > servingsToTrack)
                    Text(
                      '${totalServingsToDeduct - servingsToTrack} ${totalServingsToDeduct - servingsToTrack == 1 ? 'serving' : 'servings'} available as leftovers',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(controller.error!),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cooking recipe: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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

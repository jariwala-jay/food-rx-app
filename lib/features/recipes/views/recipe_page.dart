import 'package:flutter/material.dart';
import 'package:flutter_app/features/recipes/widgets/recipe_card.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/views/create_recipe_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/features/recipes/models/nutrition.dart';
import 'package:flutter_app/features/recipes/views/saved_recipes_page.dart';

// State class for efficient rebuilds
class RecipePageState {
  final List<Recipe> recipes;
  final bool isLoading;
  final String? error;
  final List<String> userMedicalConditionsDisplay;

  const RecipePageState({
    required this.recipes,
    required this.isLoading,
    required this.error,
    required this.userMedicalConditionsDisplay,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipePageState &&
        other.recipes.length == recipes.length &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.userMedicalConditionsDisplay.length ==
            userMedicalConditionsDisplay.length;
  }

  @override
  int get hashCode {
    return recipes.length.hashCode ^
        isLoading.hashCode ^
        error.hashCode ^
        userMedicalConditionsDisplay.length.hashCode;
  }
}

class RecipePage extends StatefulWidget {
  const RecipePage({Key? key}) : super(key: key);

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize the recipe controller when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitialized) {
        _hasInitialized = true;
        Provider.of<RecipeController>(context, listen: false).initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header with title
              Row(
                children: [
                  const Text(
                    'Recipes',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.bookmark_outline),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SavedRecipesPage()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Main content
              Expanded(
                child: Selector<RecipeController, RecipePageState>(
                  selector: (_, controller) => RecipePageState(
                    recipes: controller.recipes,
                    isLoading: controller.isLoading,
                    error: controller.error,
                    userMedicalConditionsDisplay:
                        controller.userMedicalConditionsDisplay,
                  ),
                  builder: (context, state, child) {
                    if (kDebugMode) {
                      print(
                          '🏗️ RecipePage Selector rebuild: ${state.recipes.length} recipes, loading: ${state.isLoading}');
                    }

                    if (state.isLoading) {
                      return _buildLoadingState();
                    }

                    if (state.error != null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Something went wrong',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                final controller =
                                    Provider.of<RecipeController>(context,
                                        listen: false);
                                controller.clearError();
                                // Only initialize if not already initialized
                                if (!_hasInitialized) {
                                  _hasInitialized = true;
                                  controller.initialize();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6A00),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (state.recipes.isNotEmpty) {
                      return _buildRecipeList(state);
                    }

                    // Empty state - show discovery option
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Turn Your Pantry into Delicious Meals',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildButton('Generate Recipes', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateRecipeView(),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeList(RecipePageState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Medical conditions indicator
        if (state.userMedicalConditionsDisplay.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F8FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE3F2FD)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.health_and_safety,
                  color: Colors.blue[600],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Filtered for: ${state.userMedicalConditionsDisplay.join(', ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Text(
          'Recommended for you (${state.recipes.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: state.recipes.length,
            itemBuilder: (context, index) {
              final Recipe recipe = state.recipes[index];
              return RecipeCard(recipe: recipe);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEEFE4),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search,
              color: Color(0xFFFF6A00),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFF6A00),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecipeDetails(Recipe recipe) {
    // This is now handled by the GestureDetector on the card
  }

  String _formatIngredient(RecipeIngredient ingredient) {
    String amount;
    // Format the amount to show decimals only if necessary
    if (ingredient.amount == ingredient.amount.truncate()) {
      amount = ingredient.amount.toInt().toString();
    } else {
      amount = ingredient.amount.toStringAsFixed(2);
    }

    // Handle pluralization of the unit
    String unit = ingredient.unit;
    if (ingredient.amount > 1 && !unit.endsWith('s')) {
      if (unit.isNotEmpty) {
        unit = '${unit}s';
      }
    }

    return '$amount $unit ${ingredient.name}';
  }

  Widget _buildNutritionSummary(Recipe recipe) {
    final nutrition = recipe.nutrition;
    if (nutrition == null) return const SizedBox.shrink();

    // Helper to find a nutrient by name
    Nutrient? findNutrient(String name) {
      try {
        return nutrition.nutrients.firstWhere(
          (n) => n.name.toLowerCase() == name.toLowerCase(),
        );
      } catch (e) {
        return null; // Not found
      }
    }

    final calories = findNutrient('calories');
    final protein = findNutrient('protein');
    final fat = findNutrient('fat');
    final carbs = findNutrient('carbohydrates');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nutrition Facts (per serving)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          recipe.summary.replaceAll(RegExp(r'<[^>]*>'), ''),
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            if (calories != null)
              _buildNutritionTile(
                  'Calories', '${calories.amount.toInt()}', Colors.orange),
            if (protein != null)
              _buildNutritionTile(
                  'Protein', '${protein.amount.toInt()}g', Colors.green),
            if (fat != null)
              _buildNutritionTile('Fat', '${fat.amount.toInt()}g', Colors.blue),
            if (carbs != null)
              _buildNutritionTile(
                  'Carbs', '${carbs.amount.toInt()}g', Colors.red),
          ],
        )
      ],
    );
  }

  Widget _buildNutritionTile(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 4,
            backgroundColor: color,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _cookRecipe(Recipe recipe) {
    final controller = Provider.of<RecipeController>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cook Recipe'),
        content: Text(
          'Are you sure you want to cook "${recipe.title}"? This will deduct available ingredients from pantry and track ALL recipe ingredients for nutrition.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Capture the ScaffoldMessenger and Navigator from a context that will remain valid.
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              // Pop the dialog first, then the modal sheet.
              Navigator.pop(dialogContext);
              navigator.pop();

              // Show loading indicator using the captured ScaffoldMessenger.
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Row(
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
                      SizedBox(width: 16),
                      Text('Cooking recipe and updating trackers...'),
                    ],
                  ),
                  duration: Duration(seconds: 3),
                  backgroundColor: Colors.orange,
                ),
              );

              try {
                await controller.cookRecipe(recipe);

                // Check if the widget is still in the tree before showing another SnackBar.
                if (!mounted) return;

                if (controller.error == null) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Recipe cooked successfully! Available pantry items deducted and ALL recipe ingredients tracked for nutrition.'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4),
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(controller.error!),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                // Handle any unexpected errors
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error cooking recipe: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6A00),
              foregroundColor: Colors.white,
            ),
            child: const Text('Cook'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFFF6A00),
          ),
          const SizedBox(height: 20),
          const Text(
            'Finding makeable recipes...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzing your pantry for the best matches',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/models/prepared_recipe.dart';
import 'package:flutter_app/features/recipes/views/recipe_detail_page.dart';
import 'package:flutter_app/features/recipes/widgets/servings_consumed_modal.dart';
import 'package:flutter_app/core/widgets/cached_network_image.dart';

/// List of prepared recipes (leftovers). Tap leftover servings to log more consumption.
class PreparedRecipesPage extends StatefulWidget {
  const PreparedRecipesPage({Key? key}) : super(key: key);

  @override
  State<PreparedRecipesPage> createState() => _PreparedRecipesPageState();
}

class _PreparedRecipesPageState extends State<PreparedRecipesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RecipeController>(context, listen: false)
          .loadPreparedRecipes();
    });
  }

  Future<void> _onTapLeftover(PreparedRecipe item) async {
    final remaining = item.remainingServings;
    if (remaining <= 0) return;

    final remainingText = remaining == remaining.truncateToDouble()
        ? remaining.toInt().toString()
        : remaining.toStringAsFixed(2);
    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ServingsConsumedModal(
        recipeServings: remaining.ceil().clamp(1, 999),
        maxServings: remaining,
        subtitle:
            'You have $remainingText serving${remaining == 1 ? '' : 's'} left.',
      ),
    );

    if (result == null || !mounted) return;

    final toLog = result.clamp(0.0, remaining);
    if (toLog <= 0) return;

    final controller = Provider.of<RecipeController>(context, listen: false);
    try {
      await controller.logConsumptionFromPrepared(item, toLog);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged ${toLog == toLog.truncateToDouble() ? toLog.toInt() : toLog.toStringAsFixed(2)} serving(s). Pantry and goals updated.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRecipeActionSheet(BuildContext context, PreparedRecipe item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final canLog = item.remainingServings > 0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.recipe.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2C),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecipeDetailPage(
                          recipe: item.recipe,
                          fromPreparedRecipes: true,
                          leftoverServings: item.remainingServings,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book_outlined, size: 22),
                  label: const Text('See recipe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: !canLog
                      ? null
                      : () {
                          Navigator.pop(context);
                          _onTapLeftover(item);
                        },
                  icon: const Icon(Icons.restaurant, size: 22),
                  label: const Text('Log the servings left'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canLog
                        ? const Color(0xFFFF6A00)
                        : Colors.grey.shade300,
                    foregroundColor:
                        canLog ? Colors.white : Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Prepared recipes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
      ),
      body: Consumer<RecipeController>(
        builder: (context, controller, _) {
          final list = controller.preparedRecipes;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_outlined,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No prepared recipes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cook a recipe to get started.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              return _PreparedRecipeCard(
                item: item,
                onTapLeftover: () => _onTapLeftover(item),
                onTapCard: () => _showRecipeActionSheet(context, item),
              );
            },
          );
        },
      ),
    );
  }
}

class _PreparedRecipeCard extends StatelessWidget {
  final PreparedRecipe item;
  final VoidCallback onTapLeftover;
  final VoidCallback onTapCard;

  const _PreparedRecipeCard({
    required this.item,
    required this.onTapLeftover,
    required this.onTapCard,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = item.remainingServings;
    final remainingText = remaining == remaining.truncateToDouble()
        ? remaining.toInt().toString()
        : remaining.toStringAsFixed(2);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTapCard,
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: RecipeImage(
                    imageUrl: item.recipe.image,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.recipe.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C2C2C),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: remaining > 0 ? onTapLeftover : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: remaining > 0
                                ? const Color(0xFFFF6A00)
                                    .withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: remaining > 0
                                  ? const Color(0xFFFF6A00)
                                  : Colors.grey,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.restaurant,
                                size: 16,
                                color: remaining > 0
                                    ? const Color(0xFFFF6A00)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$remainingText serving${remaining == 1 ? '' : 's'} left',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: remaining > 0
                                      ? const Color(0xFFFF6A00)
                                      : Colors.grey[700],
                                ),
                              ),
                              if (remaining > 0) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 16,
                                  color: const Color(0xFFFF6A00),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

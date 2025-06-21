import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/widgets/recipe_card.dart';

class SavedRecipesPage extends StatelessWidget {
  const SavedRecipesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<RecipeController>(
      builder: (context, controller, child) {
        final savedRecipes = controller.savedRecipes;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Saved Recipes'),
            backgroundColor: const Color(0xFFF7F7F8),
            elevation: 0,
            foregroundColor: Colors.black87,
            centerTitle: true,
          ),
          backgroundColor: const Color(0xFFF7F7F8),
          body: savedRecipes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No saved recipes yet',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your saved recipes will appear here.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: savedRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = savedRecipes[index];
                    return RecipeCard(recipe: recipe, fromSaved: false);
                  },
                ),
        );
      },
    );
  }
}

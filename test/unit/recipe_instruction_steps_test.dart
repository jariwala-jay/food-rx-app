import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';

void main() {
  group('InstructionStep.isServingMetadata', () {
    test('detects Serves N lines', () {
      expect(InstructionStep.isServingMetadata('Serves 6'), isTrue);
      expect(InstructionStep.isServingMetadata('serves: 4'), isTrue);
    });

    test('keeps real cooking steps', () {
      expect(
        InstructionStep.isServingMetadata('Remove from oil and drain on paper towel.'),
        isFalse,
      );
    });
  });

  group('InstructionStep.isVideoPlaceholder', () {
    test('detects Whatch video typo from Spoonacular', () {
      expect(InstructionStep.isVideoPlaceholder('Whatch video'), isTrue);
      expect(InstructionStep.isVideoPlaceholder('Watch the video'), isTrue);
    });

    test('keeps real cooking steps', () {
      expect(
        InstructionStep.isVideoPlaceholder(
          'Toss broccoli with garlic, lemon juice, and chili flakes.',
        ),
        isFalse,
      );
    });
  });

  group('Recipe.hasCookingInstructions', () {
    test('false for video-only recipe', () {
      final recipe = Recipe(
        id: 1,
        title: 'Test',
        image: '',
        readyInMinutes: 20,
        servings: 2,
        sourceUrl: 'https://example.com',
        summary: '',
        cuisines: const [],
        dishTypes: const [],
        diets: const [],
        extendedIngredients: const [],
        analyzedInstructions: [
          RecipeInstruction(
            name: '',
            steps: [
              InstructionStep(
                number: 1,
                step: 'Whatch video',
                ingredients: const [],
                equipment: const [],
              ),
            ],
          ),
        ],
        vegetarian: false,
        vegan: false,
        glutenFree: true,
        dairyFree: true,
        veryHealthy: false,
        cheap: false,
        veryPopular: false,
        sustainable: false,
        lowFodmap: false,
        weightWatcherSmartPoints: 0,
        gaps: '',
        pricePerServing: 0,
        aggregateLikes: 0,
        healthScore: 0,
        creditsText: '',
        license: '',
        sourceName: '',
        spoonacularScore: 0,
        spoonacularSourceUrl: '',
      );
      expect(recipe.hasCookingInstructions, isFalse);
    });
  });

  group('RecipeInstruction.cookingSteps', () {
    test('filters serving metadata from step list', () {
      final instruction = RecipeInstruction(
        name: '',
        steps: [
          InstructionStep(
            number: 1,
            step: 'Beat together egg and water.',
            ingredients: const [],
            equipment: const [],
          ),
          InstructionStep(
            number: 6,
            step: 'Serves 6',
            ingredients: const [],
            equipment: const [],
          ),
        ],
      );

      expect(instruction.cookingSteps.length, 1);
      expect(instruction.cookingSteps.first.step, contains('egg'));
    });
  });
}

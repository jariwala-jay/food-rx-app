# Real Spoonacular Test Data

This directory contains real Spoonacular API response data that can be used for testing and development of the Food Rx conversion services.

## Overview

The `SpoonacularTestData` class provides structured access to real recipe search results from Spoonacular's API, including:

- **7 real burger recipes** with complete ingredient data
- **Nutrition information** (calories, protein, fat, carbs)
- **Ingredient details** with amounts, units, and metadata
- **Helper methods** for converting to different formats

## Available Recipes

| Recipe ID | Title | Calories | Protein | Key Ingredients |
|-----------|-------|----------|---------|-----------------|
| 991010 | Chicken Ranch Burgers | 365 | 41g | Chicken, bell pepper, bread crumbs, ranch seasoning |
| 681713 | Everything Bagel Cheese Burger | 820 | 42g | Ground beef, everything bagel spice |
| 632502 | Apple Cheddar Turkey Burgers | 362 | 38g | Ground turkey, apple, cheddar cheese |
| 775621 | Gorgonzola & Grilled Peach Burger | 971 | 51g | Ground beef, gorgonzola, peaches |
| 664080 | Turkey-Spinach Burgers | 219 | 29g | Ground turkey, spinach, soy sauce |
| 645680 | Grilled Chuck Burgers | 803 | 35g | Ground chuck, cheddar, lemon garlic aioli |
| 637631 | Cheesy Bacon Burger | 475 | 49g | Ground beef, turkey bacon, chipotle aioli |

## Usage Examples

### Basic Recipe Access

```dart
import '../test_data/spoonacular_recipe_search_response.dart';

// Get all available recipe IDs
final recipeIds = SpoonacularTestData.getAllRecipeIds();

// Get a specific recipe by ID
final recipe = SpoonacularTestData.getRecipeById(991010);
print('Recipe: ${recipe['title']}');
print('Calories: ${recipe['calories']}');

// Access ingredients
final missedIngredients = recipe['missedIngredients'] as List;
final usedIngredients = recipe['usedIngredients'] as List;
```

### Recipe Scaling Tests

```dart
import 'package:flutter_app/core/services/recipe_scaling_service.dart';
import '../test_data/spoonacular_recipe_search_response.dart';

// Create a mock recipe for scaling
final recipe = SpoonacularTestData.createMockRecipeForScaling(991010);

// Scale the recipe
final scaledRecipe = recipeScalingService.scaleRecipe(
  originalRecipe: recipe,
  targetServings: 8,
);

// Verify results
expect(scaledRecipe['servings'], 8);
expect(scaledRecipe['scalingMetadata']['scaleFactor'], 2.0);
```

### Unit Conversion Tests

```dart
import 'package:flutter_app/core/services/unit_conversion_service.dart';

// Test conversions with real ingredient names from the data
final result = unitConversionService.convertWithConfidence(
  amount: 1.0,
  fromUnit: 'lb',
  toUnit: 'g',
  ingredientName: 'chicken', // Real ingredient from the data
);

expect(result['confidence'], greaterThan(0.9));
```

### Performance Testing

```dart
// Test scaling performance across all recipes
final stopwatch = Stopwatch()..start();

for (final id in SpoonacularTestData.getAllRecipeIds()) {
  final recipe = SpoonacularTestData.createMockRecipeForScaling(id);
  recipeScalingService.scaleRecipe(
    originalRecipe: recipe,
    targetServings: 6,
  );
}

stopwatch.stop();
final averageTime = stopwatch.elapsedMilliseconds / 7; // 7 recipes
expect(averageTime, lessThan(150)); // PRD requirement
```

## Data Structure

### Raw Spoonacular Format

The original search results follow Spoonacular's recipe search format:

```dart
{
  "id": 991010,
  "title": "Chicken Ranch Burgers",
  "calories": 365,
  "protein": "41g",
  "missedIngredients": [
    {
      "id": 10211821,
      "amount": 0.5,
      "unit": "medium",
      "name": "bell pepper",
      "original": "½ medium bell pepper (chopped)"
    }
  ],
  "usedIngredients": [...],
  "unusedIngredients": [...]
}
```

### Extended Ingredients Format

The `createMockRecipeForScaling()` method converts to Spoonacular's detailed recipe format:

```dart
{
  "id": 991010,
  "title": "Chicken Ranch Burgers",
  "servings": 4,
  "extendedIngredients": [
    {
      "id": 10211821,
      "name": "bell pepper",
      "amount": 0.5,
      "unit": "medium",
      "measures": {
        "us": {"amount": 0.5, "unitShort": "medium"},
        "metric": {"amount": 0.5, "unitShort": "medium"}
      }
    }
  ]
}
```

## Helper Methods

### `SpoonacularTestData.getRecipeById(int id)`
Returns the raw Spoonacular search result for a specific recipe.

### `SpoonacularTestData.getAllRecipeIds()`
Returns a list of all available recipe IDs.

### `SpoonacularTestData.convertToExtendedIngredient(Map ingredient)`
Converts a search result ingredient to extended ingredient format.

### `SpoonacularTestData.createMockRecipeForScaling(int id)`
Creates a complete recipe object suitable for testing the RecipeScalingService.

## Integration Tests

See `../integration_tests/real_data_integration_test.dart` for comprehensive examples of:

- ✅ Recipe scaling with real data
- ✅ Unit conversions with real ingredients  
- ✅ Cross-service integration testing
- ✅ Performance benchmarking
- ✅ Data validation

## Adding More Test Data

To add more recipes to the test data:

1. Get a real Spoonacular API response from `/recipes/findByIngredients`
2. Add the recipe objects to the `results` array in `spoonacular_recipe_search_response.dart`
3. Update the `totalResults` count
4. Test with the existing helper methods

## Benefits of Real Data Testing

- **Realistic edge cases**: Real ingredient names, units, and amounts
- **API compatibility**: Ensures services work with actual Spoonacular responses
- **Performance validation**: Test with realistic data sizes and complexity
- **Confidence building**: Validates conversion accuracy with real-world examples
- **Regression prevention**: Catches issues when real data structures change

## PRD Compliance Testing

This test data helps validate PRD requirements:

- **Accuracy**: ≤5% variance with real ingredient conversions
- **Performance**: <150ms response time per recipe
- **Confidence**: ≥95% confidence for common ingredients
- **Reliability**: 99.9% success rate with real data

Use this data to ensure your services meet all Food Rx PRD specifications! 
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/diet_serving_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';

void main() {
  group('DietServingService Tests', () {
    late DietServingService dietService;
    late UnitConversionService conversionService;

    setUp(() {
      conversionService = UnitConversionService();
      dietService = DietServingService(conversionService: conversionService);
    });

    group('Category Mapping Tests', () {
      test('should map vegetables correctly', () {
        final categories = dietService.getCategoriesForIngredient('tomato');
        expect(categories, contains(TrackerCategory.veggies));
      });

      test('should map fruits correctly', () {
        final categories = dietService.getCategoriesForIngredient('apple');
        expect(categories, contains(TrackerCategory.fruits));
      });

      test('should map proteins correctly', () {
        final categories = dietService.getCategoriesForIngredient('chicken');
        expect(categories, contains(TrackerCategory.protein));
      });

      test('should map dairy correctly', () {
        final categories = dietService.getCategoriesForIngredient('milk');
        expect(categories, contains(TrackerCategory.dairy));
      });

      test('should map grains correctly', () {
        final categories = dietService.getCategoriesForIngredient('rice');
        expect(categories, contains(TrackerCategory.grains));
      });

      test('should map nuts/legumes correctly', () {
        final categories = dietService.getCategoriesForIngredient('almond');
        expect(categories, contains(TrackerCategory.nutsLegumes));
      });

      test('should map fats/oils correctly', () {
        final categories = dietService.getCategoriesForIngredient('olive oil');
        expect(categories, contains(TrackerCategory.fatsOils));
      });

      test('should map sweets correctly', () {
        final categories = dietService.getCategoriesForIngredient('sugar');
        expect(categories, contains(TrackerCategory.sweets));
      });

      test('should handle multiple categories', () {
        final categories = dietService.getCategoriesForIngredient('peanut butter');
        expect(categories, contains(TrackerCategory.nutsLegumes));
        expect(categories, contains(TrackerCategory.fatsOils));
      });

      test('should handle case insensitive matching', () {
        final categories = dietService.getCategoriesForIngredient('CHICKEN BREAST');
        expect(categories, contains(TrackerCategory.protein));
      });
    });

    group('DASH Diet Serving Calculations', () {
      test('should calculate vegetable servings correctly', () {
        // 1 cup raw leafy vegetables = 90g = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'spinach',
          amount: 90.0,
          unit: 'gram',
          category: TrackerCategory.veggies,
          dietType: 'dash',
        );
        expect(servings, closeTo(1.0, 0.1));
      });

      test('should calculate fruit servings correctly', () {
        // 1 medium apple ≈ 182g, DASH serving = 120g
        final servings = dietService.getServingsForTracker(
          ingredientName: 'apple',
          amount: 120.0,
          unit: 'gram',
          category: TrackerCategory.fruits,
          dietType: 'dash',
        );
        expect(servings, closeTo(1.0, 0.1));
      });

      test('should calculate grain servings correctly', () {
        // 1 slice bread ≈ 30g = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'bread',
          amount: 30.0,
          unit: 'gram',
          category: TrackerCategory.grains,
          dietType: 'dash',
        );
        expect(servings, closeTo(1.0, 0.1));
      });

      test('should calculate protein servings correctly', () {
        // 1 oz cooked chicken = 28g = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'chicken',
          amount: 28.0,
          unit: 'gram',
          category: TrackerCategory.protein,
          dietType: 'dash',
        );
        expect(servings, closeTo(1.0, 0.1));
      });

      test('should calculate dairy servings correctly', () {
        // 1 cup milk = 245ml = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'milk',
          amount: 245.0,
          unit: 'milliliter',
          category: TrackerCategory.dairy,
          dietType: 'dash',
        );
        expect(servings, closeTo(1.0, 0.1));
      });

      test('should calculate nuts/legumes servings correctly', () {
        // 1/3 cup nuts = 42g = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'almonds',
          amount: 42.0,
          unit: 'gram',
          category: TrackerCategory.nutsLegumes,
          dietType: 'dash',
        );
        expect(servings, closeTo(1.0, 0.1));
      });

      test('should calculate fats/oils servings correctly', () {
        // 1 tsp oil = 5ml = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'olive oil',
          amount: 5.0,
          unit: 'milliliter',
          category: TrackerCategory.fatsOils,
          dietType: 'dash',
        );
        expect(servings, closeTo(1.0, 0.1));
      });

      test('should calculate sweets servings correctly', () {
        // 1 tbsp sugar = 15g = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'sugar',
          amount: 15.0,
          unit: 'gram',
          category: TrackerCategory.sweets,
          dietType: 'dash',
        );
        expect(servings, closeTo(1.0, 0.1));
      });
    });

    group('MyPlate Diet Serving Calculations', () {
      test('should calculate vegetable servings correctly', () {
        // 1 cup vegetables = 125g = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'broccoli',
          amount: 125.0,
          unit: 'gram',
          category: TrackerCategory.veggies,
          dietType: 'myplate',
        );
        expect(servings, closeTo(1.0, 0.1));
      });

      test('should calculate fruit servings correctly', () {
        // 1 cup fruit = 150g = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'banana',
          amount: 150.0,
          unit: 'gram',
          category: TrackerCategory.fruits,
          dietType: 'myplate',
        );
        expect(servings, closeTo(1.0, 0.1));
      });

      test('should calculate grain servings correctly', () {
        // 1 oz grains = 28g = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'rice',
          amount: 28.0,
          unit: 'gram',
          category: TrackerCategory.grains,
          dietType: 'myplate',
        );
        expect(servings, closeTo(1.0, 0.1));
      });

      test('should calculate protein servings correctly', () {
        // 1 oz protein = 28g = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'salmon',
          amount: 28.0,
          unit: 'gram',
          category: TrackerCategory.protein,
          dietType: 'myplate',
        );
        expect(servings, closeTo(1.0, 0.1));
      });

      test('should calculate dairy servings correctly', () {
        // 1 cup dairy = 245ml = 1 serving
        final servings = dietService.getServingsForTracker(
          ingredientName: 'yogurt',
          amount: 245.0,
          unit: 'milliliter',
          category: TrackerCategory.dairy,
          dietType: 'myplate',
        );
        expect(servings, closeTo(1.0, 0.1));
      });
    });

    group('Unit Conversion Integration Tests', () {
      test('should convert cups to grams for vegetables', () {
        // 1 cup raw spinach ≈ 30g, DASH serving = 90g
        final servings = dietService.getServingsForTracker(
          ingredientName: 'spinach',
          amount: 1.0,
          unit: 'cup',
          category: TrackerCategory.veggies,
          dietType: 'dash',
        );
        expect(servings, greaterThan(0.0));
      });

      test('should convert ounces to grams for protein', () {
        // 3 oz chicken = 85g, DASH serving = 28g
        final servings = dietService.getServingsForTracker(
          ingredientName: 'chicken',
          amount: 3.0,
          unit: 'ounce',
          category: TrackerCategory.protein,
          dietType: 'dash',
        );
        expect(servings, closeTo(3.0, 0.3)); // Should be about 3 servings
      });

      test('should convert tablespoons to milliliters for fats', () {
        // 1 tbsp oil = 14.8ml, DASH serving = 5ml
        final servings = dietService.getServingsForTracker(
          ingredientName: 'olive oil',
          amount: 1.0,
          unit: 'tablespoon',
          category: TrackerCategory.fatsOils,
          dietType: 'dash',
        );
        expect(servings, closeTo(3.0, 0.3)); // Should be about 3 servings
      });

      test('should handle piece-based conversions', () {
        // 1 medium apple ≈ 182g, DASH serving = 120g
        final servings = dietService.getServingsForTracker(
          ingredientName: 'apple',
          amount: 1.0,
          unit: 'piece',
          category: TrackerCategory.fruits,
          dietType: 'dash',
        );
        expect(servings, greaterThan(1.0));
      });
    });

    group('Recipe Serving Calculations', () {
      test('should calculate servings for multiple ingredients', () {
        final ingredients = [
          {'name': 'chicken breast', 'amount': 200, 'unit': 'gram'},
          {'name': 'broccoli', 'amount': 150, 'unit': 'gram'},
          {'name': 'brown rice', 'amount': 60, 'unit': 'gram'},
          {'name': 'olive oil', 'amount': 1, 'unit': 'tablespoon'},
        ];

        final servings = dietService.calculateRecipeServings(
          ingredients: ingredients,
          dietType: 'dash',
          servings: 2, // Recipe serves 2 people
        );

        expect(servings[TrackerCategory.leanMeat], greaterThan(0.0)); // DASH uses leanMeat
        expect(servings[TrackerCategory.veggies], greaterThan(0.0));
        expect(servings[TrackerCategory.grains], greaterThan(0.0));
        expect(servings[TrackerCategory.fatsOils], greaterThan(0.0));
      });

      test('should handle empty ingredient list', () {
        final servings = dietService.calculateRecipeServings(
          ingredients: [],
          dietType: 'dash',
          servings: 1,
        );
        expect(servings, isEmpty);
      });
    });

    group('Validation Tests', () {
      test('should validate successful conversion', () {
        final validation = dietService.validateServingConversion(
          ingredientName: 'chicken',
          amount: 100.0,
          unit: 'gram',
          category: TrackerCategory.leanMeat, // DASH uses leanMeat
          dietType: 'dash',
        );

        expect(validation['canConvert'], isTrue);
        expect(validation['confidence'], greaterThan(0.90));
      });

      test('should validate failed conversion for unsupported diet', () {
        final validation = dietService.validateServingConversion(
          ingredientName: 'chicken',
          amount: 100.0,
          unit: 'gram',
          category: TrackerCategory.protein,
          dietType: 'keto', // Unsupported diet
        );

        expect(validation['canConvert'], isFalse);
        expect(validation['confidence'], equals(0.0));
      });

      test('should validate failed conversion for unsupported unit', () {
        final validation = dietService.validateServingConversion(
          ingredientName: 'chicken',
          amount: 100.0,
          unit: 'invalid_unit',
          category: TrackerCategory.leanMeat, // DASH uses leanMeat
          dietType: 'dash',
        );

        expect(validation['canConvert'], isFalse);
      });
    });

    group('Serving Definition Tests', () {
      test('should get DASH serving definition', () {
        final definition = dietService.getServingDefinition(
          category: TrackerCategory.veggies,
          dietType: 'dash',
        );

        expect(definition, isNotNull);
        expect(definition!['canonical_amount'], equals(90.0));
        expect(definition['canonical_unit'], equals('gram'));
        expect(definition['display_unit'], equals('serving'));
      });

      test('should get MyPlate serving definition', () {
        final definition = dietService.getServingDefinition(
          category: TrackerCategory.fruits,
          dietType: 'myplate',
        );

        expect(definition, isNotNull);
        expect(definition!['canonical_amount'], equals(150.0));
        expect(definition['canonical_unit'], equals('gram'));
        expect(definition['display_unit'], equals('cup'));
      });

      test('should return null for unsupported diet/category', () {
        final definition = dietService.getServingDefinition(
          category: TrackerCategory.veggies,
          dietType: 'unsupported',
        );

        expect(definition, isNull);
      });
    });

    group('Recommended Daily Servings Tests', () {
      test('should get DASH recommended servings', () {
        final recommendations = dietService.getRecommendedDailyServings('dash');

        expect(recommendations[TrackerCategory.veggies], equals(4.5));
        expect(recommendations[TrackerCategory.fruits], equals(4.5));
        expect(recommendations[TrackerCategory.grains], equals(7.0));
        expect(recommendations[TrackerCategory.leanMeat], equals(6.0)); // DASH uses leanMeat, not protein
        expect(recommendations[TrackerCategory.dairy], equals(2.5));
      });

      test('should get MyPlate recommended servings', () {
        final recommendations = dietService.getRecommendedDailyServings('myplate');

        expect(recommendations[TrackerCategory.veggies], equals(2.5));
        expect(recommendations[TrackerCategory.fruits], equals(2.0));
        expect(recommendations[TrackerCategory.grains], equals(6.0));
        expect(recommendations[TrackerCategory.protein], equals(5.5));
        expect(recommendations[TrackerCategory.dairy], equals(3.0));
      });

      test('should return empty map for unsupported diet', () {
        final recommendations = dietService.getRecommendedDailyServings('unsupported');
        expect(recommendations, isEmpty);
      });
    });

    group('Utility Tests', () {
      test('should get available diet types', () {
        final dietTypes = dietService.getAvailableDietTypes();
        expect(dietTypes, contains('dash'));
        expect(dietTypes, contains('myplate'));
      });

      test('should get tracked categories for DASH', () {
        final categories = dietService.getTrackedCategories('dash');
        expect(categories, contains(TrackerCategory.veggies));
        expect(categories, contains(TrackerCategory.fruits));
        expect(categories, contains(TrackerCategory.nutsLegumes));
        expect(categories, contains(TrackerCategory.sweets));
      });

      test('should get tracked categories for MyPlate', () {
        final categories = dietService.getTrackedCategories('myplate');
        expect(categories, contains(TrackerCategory.veggies));
        expect(categories, contains(TrackerCategory.fruits));
        expect(categories, isNot(contains(TrackerCategory.nutsLegumes)));
        expect(categories, isNot(contains(TrackerCategory.sweets)));
      });

      test('should format serving amounts correctly', () {
        final formatted = dietService.formatServingAmount(
          2.5,
          TrackerCategory.veggies,
          'dash',
        );
        expect(formatted, equals('2.5 servings'));
      });

      test('should format single serving amount correctly', () {
        final formatted = dietService.formatServingAmount(
          1.0,
          TrackerCategory.veggies,
          'dash',
        );
        expect(formatted, equals('1 serving'));
      });
    });

    group('PRD Compliance Tests', () {
      test('should meet PRD accuracy requirements for DASH vegetables', () {
        // PRD Table: DASH Vegetables = 90g
        final servings = dietService.getServingsForTracker(
          ingredientName: 'broccoli',
          amount: 90.0,
          unit: 'gram',
          category: TrackerCategory.veggies,
          dietType: 'dash',
        );
        
        // Should be exactly 1.0 serving with ≤5% variance
        expect(servings, closeTo(1.0, 0.05));
      });

      test('should meet PRD accuracy requirements for DASH grains', () {
        // PRD Table: DASH Grains = 30g (dry)
        final servings = dietService.getServingsForTracker(
          ingredientName: 'rice',
          amount: 30.0,
          unit: 'gram',
          category: TrackerCategory.grains,
          dietType: 'dash',
        );
        
        expect(servings, closeTo(1.0, 0.05));
      });

      test('should meet PRD accuracy requirements for MyPlate dairy', () {
        // PRD Table: MyPlate Dairy = 245ml (milk)
        final servings = dietService.getServingsForTracker(
          ingredientName: 'milk',
          amount: 245.0,
          unit: 'milliliter',
          category: TrackerCategory.dairy,
          dietType: 'myplate',
        );
        
        expect(servings, closeTo(1.0, 0.05));
      });

      test('should meet PRD accuracy requirements for MyPlate protein', () {
        // PRD Table: MyPlate Protein = 28g (cooked)
        final servings = dietService.getServingsForTracker(
          ingredientName: 'chicken',
          amount: 28.0,
          unit: 'gram',
          category: TrackerCategory.protein,
          dietType: 'myplate',
        );
        
        expect(servings, closeTo(1.0, 0.05));
      });

      test('should achieve ≥95% confidence for standard conversions', () {
        final validation = dietService.validateServingConversion(
          ingredientName: 'chicken breast',
          amount: 100.0,
          unit: 'gram',
          category: TrackerCategory.protein,
          dietType: 'dash',
        );

        expect(validation['confidence'], greaterThanOrEqualTo(0.95));
      });

      test('should support canonical units as specified in PRD', () {
        // Test gram conversions
        final gramValidation = dietService.validateServingConversion(
          ingredientName: 'rice',
          amount: 30.0,
          unit: 'gram',
          category: TrackerCategory.grains,
          dietType: 'dash',
        );
        expect(gramValidation['canConvert'], isTrue);

        // Test milliliter conversions
        final mlValidation = dietService.validateServingConversion(
          ingredientName: 'milk',
          amount: 245.0,
          unit: 'milliliter',
          category: TrackerCategory.dairy,
          dietType: 'myplate',
        );
        expect(mlValidation['canConvert'], isTrue);
      });
    });

    group('Performance Tests', () {
      test('should meet PRD performance requirements (<150ms)', () {
        final stopwatch = Stopwatch()..start();
        
        // Perform multiple conversions
        for (int i = 0; i < 100; i++) {
          dietService.getServingsForTracker(
            ingredientName: 'chicken',
            amount: 100.0,
            unit: 'gram',
            category: TrackerCategory.protein,
            dietType: 'dash',
          );
        }
        
        stopwatch.stop();
        final avgTime = stopwatch.elapsedMilliseconds / 100;
        
        expect(avgTime, lessThan(150.0)); // PRD requirement: <150ms
      });

      test('should handle batch recipe calculations efficiently', () {
        final ingredients = List.generate(50, (i) => {
          'name': 'ingredient_$i',
          'amount': 100.0,
          'unit': 'gram',
        });

        final stopwatch = Stopwatch()..start();
        
        dietService.calculateRecipeServings(
          ingredients: ingredients,
          dietType: 'dash',
          servings: 4,
        );
        
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(150));
      });
    });
  });
} 
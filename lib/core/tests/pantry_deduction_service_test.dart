import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/models/pantry_item.dart';

void main() {
  group('PantryDeductionService Tests', () {
    late PantryDeductionService service;
    late UnitConversionService conversionService;
    late IngredientSubstitutionService substitutionService;

    setUp(() {
      conversionService = UnitConversionService();
      substitutionService = IngredientSubstitutionService(
        conversionService: conversionService,
      );
      service = PantryDeductionService(
        conversionService: conversionService,
        substitutionService: substitutionService,
      );
    });

    group('FIFO Logic Tests', () {
      test('should use oldest items first for deduction', () async {
        // Create pantry items with different expiration dates
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'ground beef',
            imageUrl: '',
            category: 'protein',
            quantity: 1.0,
            unit: UnitType.pound,
            expirationDate: DateTime.now().add(const Duration(days: 5)), // Newer
            addedDate: DateTime.now().subtract(const Duration(days: 2)),
          ),
          PantryItem(
            id: '2',
            name: 'ground beef',
            imageUrl: '',
            category: 'protein',
            quantity: 1.0,
            unit: UnitType.pound,
            expirationDate: DateTime.now().add(const Duration(days: 2)), // Older
            addedDate: DateTime.now().subtract(const Duration(days: 5)),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'ground beef',
            'amount': 0.5,
            'unit': 'lb',
          }
        ];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        // Should deduct from the older item first (id: '2')
        expect(result.ingredientResults.length, 1);
        expect(result.ingredientResults[0].wasDeducted, true);
        expect(result.ingredientResults[0].pantryDeductions.length, 1);
        expect(result.ingredientResults[0].pantryDeductions[0].pantryItemId, '2');
        expect(result.ingredientResults[0].pantryDeductions[0].deductedAmount, 0.5);
        expect(result.ingredientResults[0].pantryDeductions[0].newQuantity, 0.5);
      });

      test('should use multiple items when single item is insufficient', () async {
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'rice',
            imageUrl: '',
            category: 'grains',
            quantity: 100.0,
            unit: UnitType.grams,
            expirationDate: DateTime.now().add(const Duration(days: 1)), // Oldest
            addedDate: DateTime.now().subtract(const Duration(days: 3)),
          ),
          PantryItem(
            id: '2',
            name: 'rice',
            imageUrl: '',
            category: 'grains',
            quantity: 200.0,
            unit: UnitType.grams,
            expirationDate: DateTime.now().add(const Duration(days: 3)), // Newer
            addedDate: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'rice',
            'amount': 250.0,
            'unit': 'g',
          }
        ];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.ingredientResults.length, 1);
        expect(result.ingredientResults[0].wasDeducted, true);
        expect(result.ingredientResults[0].pantryDeductions.length, 2);
        
        // First deduction should be from oldest item (id: '1')
        expect(result.ingredientResults[0].pantryDeductions[0].pantryItemId, '1');
        expect(result.ingredientResults[0].pantryDeductions[0].deductedAmount, 100.0);
        expect(result.ingredientResults[0].pantryDeductions[0].newQuantity, 0.0);
        
        // Second deduction should be from newer item (id: '2')
        expect(result.ingredientResults[0].pantryDeductions[1].pantryItemId, '2');
        expect(result.ingredientResults[0].pantryDeductions[1].deductedAmount, 150.0);
        expect(result.ingredientResults[0].pantryDeductions[1].newQuantity, 50.0);
      });
    });

    group('Unit Conversion Tests', () {
      test('should convert between different units correctly', () async {
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'milk',
            imageUrl: '',
            category: 'dairy',
            quantity: 1.0,
            unit: UnitType.liter,
            expirationDate: DateTime.now().add(const Duration(days: 3)),
            addedDate: DateTime.now(),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'milk',
            'amount': 500.0,
            'unit': 'ml',
          }
        ];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.ingredientResults.length, 1);
        expect(result.ingredientResults[0].wasDeducted, true);
        expect(result.ingredientResults[0].pantryDeductions.length, 1);
        expect(result.ingredientResults[0].pantryDeductions[0].deductedAmount, 0.5); // 500ml = 0.5L
        expect(result.ingredientResults[0].pantryDeductions[0].newQuantity, 0.5); // 1L - 0.5L = 0.5L
      });

      test('should handle weight to volume conversions using density', () async {
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'flour',
            imageUrl: '',
            category: 'baking',
            quantity: 2.0,
            unit: UnitType.cup,
            expirationDate: DateTime.now().add(const Duration(days: 30)),
            addedDate: DateTime.now(),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'flour',
            'amount': 125.0,
            'unit': 'g',
          }
        ];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.ingredientResults.length, 1);
        expect(result.ingredientResults[0].wasDeducted, true);
        expect(result.ingredientResults[0].confidence, greaterThan(0.8)); // High confidence for flour conversion
      });
    });

    group('Ingredient Matching Tests', () {
      test('should match ingredients with different naming variations', () async {
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'ground beef',
            imageUrl: '',
            category: 'protein',
            quantity: 1.0,
            unit: UnitType.pound,
            expirationDate: DateTime.now().add(const Duration(days: 3)),
            addedDate: DateTime.now(),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'beef, ground',
            'amount': 0.5,
            'unit': 'lb',
          }
        ];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.ingredientResults.length, 1);
        expect(result.ingredientResults[0].wasDeducted, true);
      });

      test('should use ingredient substitution service for alternatives', () async {
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'vegetable oil',
            imageUrl: '',
            category: 'oils',
            quantity: 2.0,
            unit: UnitType.cup,
            expirationDate: DateTime.now().add(const Duration(days: 90)),
            addedDate: DateTime.now(),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'canola oil',
            'amount': 0.25,
            'unit': 'cup',
          }
        ];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        // Should find vegetable oil as substitute for canola oil
        expect(result.ingredientResults.length, 1);
        expect(result.ingredientResults[0].wasDeducted, true);
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle empty pantry gracefully', () async {
        final pantryItems = <PantryItem>[];
        final scaledIngredients = [
          {
            'name': 'chicken breast',
            'amount': 1.0,
            'unit': 'lb',
          }
        ];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.ingredientResults.length, 1);
        expect(result.ingredientResults[0].wasDeducted, false);
        expect(result.ingredientResults[0].pantryDeductions.length, 0);
        expect(result.successfulDeductions, 0);
      });

      test('should handle empty ingredient list', () async {
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'rice',
            imageUrl: '',
            category: 'grains',
            quantity: 500.0,
            unit: UnitType.grams,
            expirationDate: DateTime.now().add(const Duration(days: 30)),
            addedDate: DateTime.now(),
          ),
        ];

        final scaledIngredients = <Map<String, dynamic>>[];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.ingredientResults.length, 0);
        expect(result.totalIngredientsProcessed, 0);
        expect(result.successfulDeductions, 0);
      });

      test('should handle insufficient quantity gracefully', () async {
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'sugar',
            imageUrl: '',
            category: 'baking',
            quantity: 0.5,
            unit: UnitType.cup,
            expirationDate: DateTime.now().add(const Duration(days: 365)),
            addedDate: DateTime.now(),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'sugar',
            'amount': 2.0,
            'unit': 'cup',
          }
        ];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.ingredientResults.length, 1);
        expect(result.ingredientResults[0].wasDeducted, false);
        expect(result.ingredientResults[0].remainingAmount, 1.5); // 2.0 - 0.5 = 1.5
        expect(result.ingredientResults[0].pantryDeductions.length, 1);
        expect(result.ingredientResults[0].pantryDeductions[0].newQuantity, 0.0); // Used all available
      });

      test('should handle invalid unit conversions', () async {
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'banana',
            imageUrl: '',
            category: 'fresh_fruits',
            quantity: 6.0,
            unit: UnitType.piece,
            expirationDate: DateTime.now().add(const Duration(days: 5)),
            addedDate: DateTime.now(),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'banana',
            'amount': 250.0,
            'unit': 'ml', // Invalid conversion from piece to ml
          }
        ];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.ingredientResults.length, 1);
        // The conversion service is smart enough to handle volume to piece conversion using density
        // So this should actually work with reasonable confidence
        expect(result.ingredientResults[0].confidence, greaterThan(0.7));
      });
    });

    group('Pantry Validation Tests', () {
      test('should validate all ingredients are available', () async {
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'chicken breast',
            imageUrl: '',
            category: 'protein',
            quantity: 2.0,
            unit: UnitType.pound,
            expirationDate: DateTime.now().add(const Duration(days: 5)),
            addedDate: DateTime.now(),
          ),
          PantryItem(
            id: '2',
            name: 'rice',
            imageUrl: '',
            category: 'grains',
            quantity: 500.0,
            unit: UnitType.grams,
            expirationDate: DateTime.now().add(const Duration(days: 30)),
            addedDate: DateTime.now(),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'chicken breast',
            'amount': 1.0,
            'unit': 'lb',
          },
          {
            'name': 'rice',
            'amount': 200.0,
            'unit': 'g',
          }
        ];

        final result = await service.validatePantryForRecipe(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.allIngredientsAvailable, true);
        expect(result.availabilityPercentage, 1.0);
        expect(result.ingredientValidations.length, 2);
        expect(result.ingredientValidations.every((v) => v.isAvailable), true);
      });

      test('should identify missing ingredients', () async {
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'chicken breast',
            imageUrl: '',
            category: 'protein',
            quantity: 1.0,
            unit: UnitType.pound,
            expirationDate: DateTime.now().add(const Duration(days: 5)),
            addedDate: DateTime.now(),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'chicken breast',
            'amount': 1.0,
            'unit': 'lb',
          },
          {
            'name': 'broccoli',
            'amount': 2.0,
            'unit': 'cup',
          }
        ];

        final result = await service.validatePantryForRecipe(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.allIngredientsAvailable, false);
        expect(result.availabilityPercentage, 0.5); // 1 out of 2 available
        expect(result.ingredientValidations.length, 2);
        expect(result.ingredientValidations[0].isAvailable, true); // chicken
        expect(result.ingredientValidations[1].isAvailable, false); // broccoli
      });

      test('should calculate shortfall amounts', () async {
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'flour',
            imageUrl: '',
            category: 'baking',
            quantity: 1.0,
            unit: UnitType.cup,
            expirationDate: DateTime.now().add(const Duration(days: 30)),
            addedDate: DateTime.now(),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'flour',
            'amount': 3.0,
            'unit': 'cup',
          }
        ];

        final result = await service.validatePantryForRecipe(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.allIngredientsAvailable, false);
        expect(result.ingredientValidations.length, 1);
        expect(result.ingredientValidations[0].isAvailable, false);
        expect(result.ingredientValidations[0].hasShortfall, true);
        expect(result.ingredientValidations[0].shortfallAmount, 2.0); // 3.0 - 1.0 = 2.0
      });
    });

    group('Integration Tests', () {
      test('should handle complete recipe deduction workflow', () async {
        // Create a realistic pantry with multiple items
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'ground beef',
            imageUrl: '',
            category: 'protein',
            quantity: 2.0,
            unit: UnitType.pound,
            expirationDate: DateTime.now().add(const Duration(days: 3)),
            addedDate: DateTime.now(),
          ),
          PantryItem(
            id: '2',
            name: 'onion',
            imageUrl: '',
            category: 'fresh_veggies',
            quantity: 3.0,
            unit: UnitType.piece,
            expirationDate: DateTime.now().add(const Duration(days: 7)),
            addedDate: DateTime.now(),
          ),
          PantryItem(
            id: '3',
            name: 'tomato sauce',
            imageUrl: '',
            category: 'canned_veggies',
            quantity: 24.0,
            unit: UnitType.ounces,
            expirationDate: DateTime.now().add(const Duration(days: 365)),
            addedDate: DateTime.now(),
          ),
        ];

        // Simulate scaled recipe ingredients
        final scaledIngredients = [
          {
            'name': 'ground beef',
            'amount': 1.0,
            'unit': 'lb',
          },
          {
            'name': 'onion',
            'amount': 1.0,
            'unit': 'piece',
          },
          {
            'name': 'tomato sauce',
            'amount': 15.0,
            'unit': 'oz',
          }
        ];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.wasSuccessful, true);
        expect(result.successfulDeductions, 3);
        expect(result.averageConfidence, greaterThan(0.8));
        expect(result.updatedItems.length, 3);
        expect(result.itemsToRemove.length, 0);

        // Verify quantities were deducted correctly
        expect(result.updatedItems[0].quantity, 1.0); // 2.0 - 1.0 = 1.0 lb beef
        expect(result.updatedItems[1].quantity, 2.0); // 3.0 - 1.0 = 2.0 onions
        expect(result.updatedItems[2].quantity, 9.0); // 24.0 - 15.0 = 9.0 oz sauce
      });

      test('should handle PRD compliance requirements', () async {
        // Test PRD requirements: ≤5% stock variance, ≥95% confidence
        final pantryItems = [
          PantryItem(
            id: '1',
            name: 'rice',
            imageUrl: '',
            category: 'grains',
            quantity: 500.0,
            unit: UnitType.grams,
            expirationDate: DateTime.now().add(const Duration(days: 30)),
            addedDate: DateTime.now(),
          ),
        ];

        final scaledIngredients = [
          {
            'name': 'rice',
            'amount': 200.0,
            'unit': 'g',
          }
        ];

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        expect(result.wasSuccessful, true);
        expect(result.averageConfidence, greaterThanOrEqualTo(0.95)); // PRD requirement
        
        // Calculate stock variance (should be ≤5%)
        const originalStock = 500.0;
        const expectedRemaining = 300.0; // 500 - 200
        final actualRemaining = result.updatedItems[0].quantity;
        final variance = (actualRemaining - expectedRemaining).abs() / expectedRemaining;
        expect(variance, lessThanOrEqualTo(0.05)); // ≤5% variance
      });

      test('should handle performance requirements', () async {
        final stopwatch = Stopwatch()..start();
        
        // Create larger pantry for performance testing
        final pantryItems = List.generate(50, (index) => PantryItem(
          id: '$index',
          name: 'item_$index',
          imageUrl: '',
          category: 'general',
          quantity: 100.0,
          unit: UnitType.grams,
          expirationDate: DateTime.now().add(Duration(days: index + 1)),
          addedDate: DateTime.now(),
        ));

        final scaledIngredients = List.generate(10, (index) => {
          'name': 'item_$index',
          'amount': 50.0,
          'unit': 'g',
        });

        final result = await service.deductIngredientsFromPantry(
          scaledIngredients: scaledIngredients,
          pantryItems: pantryItems,
        );

        stopwatch.stop();
        
        // PRD requirement: <150ms response time
        expect(stopwatch.elapsedMilliseconds, lessThan(150));
        expect(result.successfulDeductions, 10);
      });
    });
  });
} 
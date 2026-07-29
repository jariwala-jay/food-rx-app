import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/utils/ingredient_nutritional_category.dart';
import 'package:flutter_app/features/recipes/utils/recipe_ingredient_pantry_counts.dart';

/// Result of the Point 1 main-ingredient validation gate.
class MainIngredientValidationResult {
  final bool passes;
  final String? mainIngredientName;
  final IngredientNutritionalCategory? mainCategory;
  final bool gateSkipped;

  const MainIngredientValidationResult({
    required this.passes,
    this.mainIngredientName,
    this.mainCategory,
    this.gateSkipped = false,
  });

  const MainIngredientValidationResult.skipped()
      : passes = true,
        mainIngredientName = null,
        mainCategory = null,
        gateSkipped = true;
}

/// Drops recipes whose defining ingredient is not in the user's pantry. Main
/// ingredient is the title's named protein if any, else the top protein in
/// the ingredient list, else the highest-importance non-seasoning item.
/// Seasonings/condiments/water/stocks never count as main; skipped entirely
/// when the pantry has no meaningful items to check against.
class RecipeMainIngredientValidator {
  RecipeMainIngredientValidator({
    RecipeIngredientPantryCounts? counts,
    PantryDeductionService? pantryService,
  }) : _pantryService = pantryService ??
            PantryDeductionService(
              conversionService: UnitConversionService(),
              substitutionService: IngredientSubstitutionService(
                conversionService: UnitConversionService(),
              ),
            ) {
    _counts = counts ?? RecipeIngredientPantryCounts(_pantryService);
  }

  late final RecipeIngredientPantryCounts _counts;
  final PantryDeductionService _pantryService;

  /// Longer names first so "chicken" wins over shorter tokens.
  static const List<String> _titleProteinKeywords = [
    'chicken',
    'salmon',
    'turkey',
    'shrimp',
    'prawn',
    'paneer',
    'bacon',
    'sausage',
    'chorizo',
    'beef',
    'pork',
    'lamb',
    'tofu',
    'tempeh',
    'tuna',
    'fish',
    'duck',
    'clam',
    'mussel',
    'egg',
    'ham',
  ];

  /// True when the user has at least one meaningful pantry item to enforce against.
  static bool shouldEnforceGate(Iterable<PantryItem> pantry) {
    final selection =
        IngredientNutritionalCategoryResolver.selectForSpoonacularInclude(
      pantry.map((item) => (name: item.name, category: item.category)),
    );
    return selection.includedNames.isNotEmpty;
  }

  /// Protein family named in the recipe title, if any (e.g. "chicken").
  static String? proteinKeywordFromTitle(String title) {
    final lower = title.toLowerCase();
    for (final keyword in _titleProteinKeywords) {
      final pattern = RegExp('\\b${RegExp.escape(keyword)}s?\\b');
      if (pattern.hasMatch(lower)) return keyword;
    }
    return null;
  }

  MainIngredientValidationResult validate(
    Recipe recipe,
    List<PantryItem> pantry,
  ) {
    if (!shouldEnforceGate(pantry)) {
      return const MainIngredientValidationResult.skipped();
    }

    final available = pantry.where((item) => !item.isExpired).toList();

    // Title protein wins: "Beer Can Chicken" requires chicken in pantry,
    // even if onion has a large amount in the ingredient list.
    final titleProtein = proteinKeywordFromTitle(recipe.title);
    if (titleProtein != null) {
      final inPantry =
          _pantryService.hasPantryMatchForIngredient(titleProtein, available);
      return MainIngredientValidationResult(
        passes: inPantry,
        mainIngredientName: titleProtein,
        mainCategory: IngredientNutritionalCategory.protein,
      );
    }

    final main = identifyMainIngredient(recipe);
    if (main == null) {
      return const MainIngredientValidationResult(
        passes: true,
        gateSkipped: false,
      );
    }

    final inPantry = _counts.isInPantry(main.ingredient, pantry);
    return MainIngredientValidationResult(
      passes: inPantry,
      mainIngredientName:
          RecipeIngredientPantryCounts.matchName(main.ingredient),
      mainCategory: main.category,
    );
  }

  /// Identifies the single defining ingredient for [recipe], if any.
  /// Used when the title does not name a protein.
  MainIngredientCandidate? identifyMainIngredient(Recipe recipe) {
    final candidates = <MainIngredientCandidate>[];

    for (final ingredient in recipe.extendedIngredients) {
      if (ingredient.isOptionalIngredient) continue;

      final name = RecipeIngredientPantryCounts.matchName(ingredient);
      if (_isExcludedFromMain(name)) continue;

      final category =
          IngredientNutritionalCategoryResolver.fromIngredientName(name);
      if (_isExcludedCategory(category)) continue;

      // Stocks / broths classified as protein must not be the main.
      if (category == IngredientNutritionalCategory.protein &&
          _isLiquidOrBaseProtein(name)) {
        continue;
      }

      final importance =
          IngredientNutritionalCategoryResolver.weightFor(category) *
              (ingredient.amount > 0 ? ingredient.amount : 0.01);

      candidates.add(
        MainIngredientCandidate(
          ingredient: ingredient,
          category: category,
          importanceScore: importance,
        ),
      );
    }

    if (candidates.isEmpty) return null;

    final proteinCandidates = candidates
        .where((c) => c.category == IngredientNutritionalCategory.protein)
        .toList();
    final pool = proteinCandidates.isNotEmpty ? proteinCandidates : candidates;

    pool.sort((a, b) => b.importanceScore.compareTo(a.importanceScore));
    return pool.first;
  }

  static bool _isExcludedCategory(IngredientNutritionalCategory category) {
    return category == IngredientNutritionalCategory.seasoning ||
        category == IngredientNutritionalCategory.condiment;
  }

  static bool _isExcludedFromMain(String ingredientName) {
    final name = ingredientName.toLowerCase().trim();
    if (name.isEmpty) return true;
    if (name == 'water') return true;
    if (name.startsWith('water ') || name.endsWith(' water')) return true;
    if (_isLiquidOrBaseProtein(name)) return true;
    if (name.contains('wine')) return true;
    if (name.contains(' bun') ||
        name.endsWith('bun') ||
        name.contains('buns')) {
      return true;
    }
    if (name.contains('breadcrumb')) return true;
    return false;
  }

  /// Broths, stocks, sauces, bouillon — supporting liquids, not the dish main.
  static bool _isLiquidOrBaseProtein(String ingredientName) {
    final name = ingredientName.toLowerCase().trim();
    return name.contains('broth') ||
        name.contains('stock') ||
        name.contains('bouillon') ||
        name.contains('better than bouillon') ||
        (name.contains('sauce') && !name.contains('apple sauce')) ||
        name.endsWith(' base') ||
        name.contains(' base ');
  }
}

class MainIngredientCandidate {
  final RecipeIngredient ingredient;
  final IngredientNutritionalCategory category;
  final double importanceScore;

  const MainIngredientCandidate({
    required this.ingredient,
    required this.category,
    required this.importanceScore,
  });
}

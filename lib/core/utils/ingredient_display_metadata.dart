/// Semantic display behaviors for ingredients the formatter cannot interpret alone.
enum DisplayBehavior {
  none,
  smallCount,
}

/// Display-only metadata for a specific ingredient.
class IngredientDisplayMetadata {
  const IngredientDisplayMetadata({
    required this.ingredient,
    required this.behavior,
  });

  final String ingredient;
  final DisplayBehavior behavior;
}

/// Step 3.1 — minimal metadata registry (display text only).
///
/// Lookup runs before [KitchenQuantityFormatter]. Never modifies ingredient amounts.
class IngredientDisplayMetadataRegistry {
  const IngredientDisplayMetadataRegistry._();

  static const Map<String, IngredientDisplayMetadata> _byKey = {
    'garlic': IngredientDisplayMetadata(
      ingredient: 'garlic',
      behavior: DisplayBehavior.smallCount,
    ),
  };

  static const Map<String, Set<String>> _aliases = {
    'garlic': {'garlic', 'fresh garlic'},
  };

  /// Resolves metadata for a display ingredient name (`nameClean` / composed name).
  static IngredientDisplayMetadata? lookup(String ingredientName) {
    final key = resolveKey(ingredientName);
    if (key == null) return null;
    return _byKey[key];
  }

  static DisplayBehavior behaviorFor(String ingredientName) {
    return lookup(ingredientName)?.behavior ?? DisplayBehavior.none;
  }

  /// Normalized metadata key, or null when no metadata applies.
  static String? resolveKey(String ingredientName) {
    final lower = ingredientName.toLowerCase().trim();
    if (lower.isEmpty) return null;

    for (final entry in _aliases.entries) {
      if (entry.value.contains(lower)) return entry.key;
    }
    return null;
  }

  /// Optional full-line override before generic formatter rules run.
  static String? formatLineOverride({
    required double amount,
    required String unit,
    required String ingredientName,
  }) {
    final metadata = lookup(ingredientName);
    if (metadata == null) return null;

    switch (metadata.behavior) {
      case DisplayBehavior.none:
        return null;
      case DisplayBehavior.smallCount:
        return _smallCountGarlicLine(
          amount: amount,
          unit: unit,
          ingredientName: ingredientName,
        );
    }
  }

  /// Garlic partial-clove display when `unit` is clove(s) and `amount` &lt; 1.
  /// Display only — nutrition/pantry/tracking still use the exact scaled
  /// value from [RecipeScalingService].
  ///
  /// Bands: &lt;0.375 → `1 small clove`, 0.375–0.625 → `1/2 clove`, ≥0.625 →
  /// `1 clove`.
  ///
  /// Does not apply to `garlic powder`, non-clove units, or amounts ≥ 1.
  static String? _smallCountGarlicLine({
    required double amount,
    required String unit,
    required String ingredientName,
  }) {
    if (amount <= 0 || amount >= 1) return null;

    final unitLower = unit.toLowerCase().trim();
    final isCloveUnit =
        unitLower == 'clove' || unitLower == 'cloves' || unitLower == 'clove garlic';
    if (!isCloveUnit) return null;

    final name = ingredientName.trim().isEmpty ? 'garlic' : ingredientName.trim();

    if (amount < 0.375) {
      return '1 small clove $name';
    }
    if (amount < 0.625) {
      return '1/2 clove $name';
    }
    return '1 clove $name';
  }
}

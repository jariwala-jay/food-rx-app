import 'ingredient_display_metadata.dart';

/// Which display code path produced a formatted ingredient line.
///
/// Used for Step 3.2 observation — distinguishes metadata overrides from
/// generic formatter rules without changing stored amounts.
enum IngredientFormatPath {
  metadataOverride('metadata_override'),
  microMeasure('micro_measure'),
  seasoningCountUnit('seasoning_count_unit'),
  produceCount('produce_count'),
  producePieceStalk('produce_piece_stalk'),
  countRange('count_range'),
  juiceOfProduce('juice_of_produce'),
  standardFormatter('standard_formatter');

  const IngredientFormatPath(this.label);

  final String label;
}

/// Display text plus the formatter path that produced it.
class FormattedIngredientLine {
  const FormattedIngredientLine({
    required this.display,
    required this.path,
  });

  final String display;
  final IngredientFormatPath path;
}

/// Ingredient category for display-only rounding rules.
enum IngredientDisplayCategory {
  /// Therapeutic/supplement ingredients — exact amounts, no cooking rounding.
  precise,
  seasoning,
  baking,
  produce,
  liquid,
  count,
  weight,
  general,
}

/// Converts exact scaled ingredient amounts into cookbook-style display text.
///
/// **Display formatting only.** Never modify [RecipeIngredient.amount] here.
/// Raw scaled amounts are used for nutrition calculations, pantry deduction,
/// and tracking. Do not assign `ingredient.amount = formatter.round(amount)`.
///
/// Milestone [version]: 50 recipe fixtures, 427 ingredients, 427/427 OK.
/// Paired baseline: `formatter_display_baseline_v1.csv`.
class KitchenQuantityFormatter {
  const KitchenQuantityFormatter();

  /// Formatter milestone tag. Bump when intentional display-rule changes ship.
  static const String version = 'v1.2';

  static const double _tinyPinchMaxTsp = 0.04;
  static const double _pinchMaxTsp = 0.10;
  static const double _eighthTsp = 0.125;
  static const double _liquidFewDropsMaxTsp = 0.02;
  static const double _liquidDrizzleMaxTsp = 0.08;
  static const double _liquidEighthTspMax = 0.25;

  static const Set<String> _volumeUnits = {
    'tsp',
    'tsp.',
    'tsps',
    'ts',
    'teaspoon',
    'teaspoons',
    'tbsp',
    'tbsp.',
    'tbsps',
    'tbs',
    'tbs.',
    'tb',
    'tb.',
    'tbl',
    'tbls',
    'tblsp',
    'tablespoon',
    'tablespoons',
    'cup',
    'cups',
    'ml',
    'milliliter',
    'milliliters',
    'l',
    'liter',
    'liters',
    'fl oz',
    'fluid ounce',
    'fluid ounces',
  };

  static const Set<String> _discreteCountUnits = {
    'bunch',
    'bunches',
    'sprig',
    'sprigs',
    'stalk',
    'stalks',
    'head',
    'heads',
    'leaf',
    'leaves',
    'slice',
    'slices',
    'can',
    'cans',
    'package',
    'packages',
    'packet',
    'packets',
  };

  static const Set<String> _wholeCountUnits = {
    '',
    'whole',
    'piece',
    'pieces',
    'item',
    'items',
    'unit',
    'units',
    'clove',
    'cloves',
    'egg',
    'eggs',
  };

  static const Set<String> _weightUnits = {
    'g',
    'gram',
    'grams',
    'kg',
    'kilogram',
    'kilograms',
    'oz',
    'ounce',
    'ounces',
    'lb',
    'lbs',
    'pound',
    'pounds',
  };

  static const Set<String> _liquidNameHints = {
    'water',
    'milk',
    'cream',
    'oil',
    'juice',
    'broth',
    'stock',
    'vinegar',
    'wine',
    'sauce',
  };

  static const Set<String> _preciseIngredientHints = {
    'supplement',
    'medication',
    'medical formula',
  };

  /// Matches Spoonacular's "juice of X" naming order (e.g. "juice of lemon").
  static final RegExp _juiceOfPattern =
      RegExp(r'^juice of (.+)$', caseSensitive: false);

  /// Matches the normalized "X juice" form (e.g. "lemon juice").
  static final RegExp _fruitJuicePattern =
      RegExp(r'^(.+) juice$', caseSensitive: false);

  /// Maps normalized ingredient name → produce count conversion.
  static const Map<String, _ProduceConversion> _produceConversions = {
    'asparagus': _ProduceConversion(
      sourceUnit: 'bunch',
      countPerSource: 20,
      countUnitSingular: 'asparagus spear',
      countUnitPlural: 'asparagus spears',
    ),
    'spring onion': _ProduceConversion(
      sourceUnit: 'bunch',
      countPerSource: 6,
      countUnitSingular: 'spring onion stalk',
      countUnitPlural: 'spring onion stalks',
    ),
    'spring onions': _ProduceConversion(
      sourceUnit: 'bunch',
      countPerSource: 6,
      countUnitSingular: 'spring onion stalk',
      countUnitPlural: 'spring onion stalks',
    ),
    'green onion': _ProduceConversion(
      sourceUnit: 'bunch',
      countPerSource: 6,
      countUnitSingular: 'green onion stalk',
      countUnitPlural: 'green onion stalks',
    ),
    'green onions': _ProduceConversion(
      sourceUnit: 'bunch',
      countPerSource: 6,
      countUnitSingular: 'green onion stalk',
      countUnitPlural: 'green onion stalks',
    ),
    'scallion': _ProduceConversion(
      sourceUnit: 'bunch',
      countPerSource: 6,
      countUnitSingular: 'scallion stalk',
      countUnitPlural: 'scallion stalks',
    ),
    'scallions': _ProduceConversion(
      sourceUnit: 'bunch',
      countPerSource: 6,
      countUnitSingular: 'scallion stalk',
      countUnitPlural: 'scallion stalks',
    ),
    'celery': _ProduceConversion(
      sourceUnit: 'bunch',
      countPerSource: 8,
      countUnitSingular: 'celery stalk',
      countUnitPlural: 'celery stalks',
    ),
    'kale': _ProduceConversion(
      sourceUnit: 'bunch',
      countPerSource: 10,
      countUnitSingular: 'kale leaf',
      countUnitPlural: 'kale leaves',
    ),
  };

  /// Full ingredient line for the recipe detail list.
  String formatIngredientLine({
    required double amount,
    required String unit,
    required String ingredientName,
    String descriptors = '',
  }) {
    return formatIngredientLineWithPath(
      amount: amount,
      unit: unit,
      ingredientName: ingredientName,
      descriptors: descriptors,
    ).display;
  }

  /// Same as [formatIngredientLine] but includes which display path was used.
  FormattedIngredientLine formatIngredientLineWithPath({
    required double amount,
    required String unit,
    required String ingredientName,
    String descriptors = '',
  }) {
    final sanitized = _sanitizeSpoonacularDisplayInput(
      amount: amount,
      unit: unit.trim(),
      ingredientName: ingredientName.trim(),
    );
    final normalizedUnit = sanitized.unit;
    final name = sanitized.name;
    final suffix = descriptors.trim();

    final metadataLine = IngredientDisplayMetadataRegistry.formatLineOverride(
      amount: sanitized.amount,
      unit: normalizedUnit,
      ingredientName: name,
    );
    if (metadataLine != null) {
      return FormattedIngredientLine(
        display: _joinLine([metadataLine, suffix]),
        path: IngredientFormatPath.metadataOverride,
      );
    }

    final juiceLine = _juiceOfProduceLineIfApplicable(
      sanitized.amount,
      normalizedUnit,
      name,
    );
    if (juiceLine != null) {
      return FormattedIngredientLine(
        display: _joinLine([juiceLine, suffix]),
        path: IngredientFormatPath.juiceOfProduce,
      );
    }

    final category = _categoryFor(name, normalizedUnit);

    final microPhrase = _microMeasurePhraseIfApplicable(
      sanitized.amount,
      normalizedUnit,
      name,
      category,
    );
    if (microPhrase != null) {
      return FormattedIngredientLine(
        display: _joinLine([microPhrase, suffix]),
        path: IngredientFormatPath.microMeasure,
      );
    }

    final seasoningCountLabel = _seasoningCountUnitLabelIfApplicable(
      sanitized.amount,
      normalizedUnit,
      name,
    );
    if (seasoningCountLabel != null) {
      return FormattedIngredientLine(
        display: _joinLine([seasoningCountLabel, suffix]),
        path: IngredientFormatPath.seasoningCountUnit,
      );
    }

    final produceBunchLabel = _produceCountLabelIfApplicable(
      sanitized.amount,
      normalizedUnit,
      name,
    );
    if (produceBunchLabel != null) {
      return FormattedIngredientLine(
        display: _joinLine([produceBunchLabel, suffix]),
        path: IngredientFormatPath.produceCount,
      );
    }

    final producePieceStalkLabel = _producePieceStalkLabelIfApplicable(
      sanitized.amount,
      normalizedUnit,
      name,
    );
    if (producePieceStalkLabel != null) {
      return FormattedIngredientLine(
        display: _joinLine([producePieceStalkLabel, suffix]),
        path: IngredientFormatPath.producePieceStalk,
      );
    }

    final converted =
        _applyDisplayUnitConversion(sanitized.amount, normalizedUnit);
    final rangeLabel = _wholeCountRangeLabelIfApplicable(
      converted.amount,
      converted.unit,
      name,
      category,
    );
    if (rangeLabel != null) {
      return FormattedIngredientLine(
        display: _joinLine([_appendNameForRange(rangeLabel, name), suffix]),
        path: IngredientFormatPath.countRange,
      );
    }

    final displayAmount = _roundForDisplay(
      converted.amount,
      converted.unit,
      category: category,
    );
    final amountLabel = category == IngredientDisplayCategory.precise
        ? _formatPreciseAmount(displayAmount)
        : formatFraction(displayAmount);
    final unitLabel = _pluralizeUnit(converted.unit, displayAmount);
    final agreedName = _agreeIngredientName(
      name,
      displayAmount,
      converted.unit,
    );

    final display = unitLabel.isEmpty
        ? _joinLine([amountLabel, agreedName, suffix])
        : _joinLine([amountLabel, unitLabel, agreedName, suffix]);
    return FormattedIngredientLine(
      display: display,
      path: IngredientFormatPath.standardFormatter,
    );
  }

  /// Numeric/fraction label only (e.g. `1/2`, `pinch`).
  String formatAmountLabel(
    double amount,
    String unit, {
    String? ingredientName,
  }) {
    final name = ingredientName ?? '';
    final category = _categoryFor(name, unit.trim());

    final microPhrase = _microMeasurePhraseIfApplicable(
      amount,
      unit.trim(),
      name,
      category,
    );
    if (microPhrase != null) {
      return microPhrase;
    }

    final converted = _applyDisplayUnitConversion(amount, unit.trim());
    final displayAmount = _roundForDisplay(
      converted.amount,
      converted.unit,
      category: category,
    );
    return formatFraction(displayAmount);
  }

  IngredientDisplayCategory categoryFor(
    String ingredientName,
    String unit,
  ) {
    return _categoryFor(ingredientName, unit);
  }

  /// Pinch / tiny-pinch phrasing for fine dry seasonings and baking micro amounts.
  String? _microMeasurePhraseIfApplicable(
    double amount,
    String unit,
    String ingredientName,
    IngredientDisplayCategory category,
  ) {
    if (!_isVolumeUnit(unit) || amount <= 0) return null;
    // Avoid "A pinch of spoon salt" when Spoonacular left "spoon" in the name.
    if (_nameContainsSpoonWord(ingredientName)) return null;

    if (category == IngredientDisplayCategory.seasoning) {
      if (amount < _tinyPinchMaxTsp) {
        return 'A tiny pinch of $ingredientName';
      }
      if (amount < _pinchMaxTsp) {
        return 'A pinch of $ingredientName';
      }
      return null;
    }

    if (category == IngredientDisplayCategory.baking) {
      if (amount < _tinyPinchMaxTsp) {
        return 'A tiny pinch of $ingredientName';
      }
      if (amount < 0.08) {
        return 'A pinch of $ingredientName';
      }
      return null;
    }

    if (category == IngredientDisplayCategory.liquid) {
      final tspAmount = _amountInTeaspoons(amount, unit);
      if (tspAmount == null) return null;
      if (tspAmount < _liquidFewDropsMaxTsp) {
        return 'A few drops of $ingredientName';
      }
      if (tspAmount < _liquidDrizzleMaxTsp) {
        return 'A drizzle of $ingredientName';
      }
      if (tspAmount < _liquidEighthTspMax) {
        return '1/8 teaspoon $ingredientName';
      }
      return null;
    }

    return null;
  }

  /// Spoonacular sometimes assigns piece/crystal/grain units to dry seasonings.
  /// Normalize those invalid count units into volume-style seasoning display.
  String? _seasoningCountUnitLabelIfApplicable(
    double amount,
    String unit,
    String ingredientName,
  ) {
    if (amount <= 0 ||
        !_seasoningHasInvalidCountUnit(unit, ingredientName)) {
      return null;
    }
    if (_nameContainsSpoonWord(ingredientName)) return null;

    if (amount <= 1) {
      return amount < _tinyPinchMaxTsp
          ? 'A tiny pinch of $ingredientName'
          : 'A pinch of $ingredientName';
    }

    // Multiple invalid "pieces" — treat count as a tsp proxy, not literal pieces.
    final tspAmount = _roundFineSeasoningTsp(amount);
    return '${formatFraction(tspAmount)} tsp $ingredientName';
  }

  static const Set<String> _invalidSeasoningCountUnits = {
    '',
    'piece',
    'pieces',
    'whole',
    'item',
    'items',
    'unit',
    'units',
    'crystal',
    'crystals',
    'grain',
    'grains',
  };

  /// Produce that may legitimately use count units — never rewrite as pinch/tsp.
  static const Set<String> _countableProduceHints = {
    'bell pepper',
    'onion',
    'shallot',
    'lemon',
    'lime',
    'avocado',
    'egg',
    'ginger',
    'garlic',
    'celery',
    'carrot',
    'potato',
    'tomato',
    'cucumber',
    'zucchini',
    'broccoli',
    'mushroom',
  };

  bool _seasoningHasInvalidCountUnit(String unit, String ingredientName) {
    final unitSingular = _singularUnit(unit.toLowerCase());
    if (!_invalidSeasoningCountUnits.contains(unitSingular)) return false;

    return _isNonCountableSeasoning(ingredientName);
  }

  bool _isNonCountableSeasoning(String ingredientName) {
    final lower = ingredientName.toLowerCase();
    if (_countableProduceHints.any(lower.contains)) return false;

    if (lower.contains('salt')) return true;
    if (lower.contains('pepper') && !lower.contains('bell')) return true;
    if (lower.contains('powder') ||
        lower.contains('ground') ||
        lower.contains('flakes')) {
      return true;
    }
    if (lower.contains('seasoning') || lower.contains('spice')) return true;

    const drySpices = [
      'paprika',
      'cumin',
      'turmeric',
      'cinnamon',
      'nutmeg',
      'oregano',
      'thyme',
      'rosemary',
      'garam masala',
      'curry powder',
      'chili powder',
      'cayenne',
    ];
    return drySpices.any(lower.contains);
  }

  double? _amountInTeaspoons(double amount, String unit) {
    final lowerUnit = unit.toLowerCase();
    if (lowerUnit == 'teaspoon' ||
        lowerUnit == 'teaspoons' ||
        lowerUnit == 'tsp') {
      return amount;
    }
    if (lowerUnit == 'tablespoon' ||
        lowerUnit == 'tablespoons' ||
        lowerUnit == 'tbsp') {
      return amount * 3;
    }
    if (lowerUnit == 'cup' || lowerUnit == 'cups') {
      return amount * 48;
    }
    return null;
  }

  /// Formats unit-less "X juice" ingredients as "juice of {qty} X" instead of
  /// a bare count, since e.g. "1 lemon juice" misreads as a bottled product.
  /// Only applies to count/whole-style units — real volume units (2 tbsp
  /// lemon juice) use standard formatting.
  String? _juiceOfProduceLineIfApplicable(
    double amount,
    String unit,
    String ingredientName,
  ) {
    if (amount <= 0) return null;

    final unitLower = unit.toLowerCase().trim();
    if (unitLower.isNotEmpty && !_wholeCountUnits.contains(unitLower)) {
      return null;
    }

    final match = _fruitJuicePattern.firstMatch(ingredientName.trim());
    if (match == null) return null;
    final fruit = match.group(1)!.trim();
    if (fruit.isEmpty) return null;

    final displayAmount = _roundGeneral(amount);
    final qty = formatFraction(displayAmount);
    final fruitLabel =
        displayAmount > 1 ? _pluralizeFruitName(fruit) : fruit;
    return 'juice of $qty $fruitLabel';
  }

  String _pluralizeFruitName(String name) {
    return name.toLowerCase().endsWith('s') ? name : '${name}s';
  }

  String? _produceCountLabelIfApplicable(
    double amount,
    String unit,
    String ingredientName,
  ) {
    if (amount <= 0) return null;

    final conversion = _produceConversionFor(ingredientName);
    if (conversion == null) return null;
    if (!_unitsMatch(unit, conversion.sourceUnit)) return null;
    if (amount >= 1) return null;

    final exactCount = amount * conversion.countPerSource;
    if (exactCount <= 0) return null;

    // When sub-bunch amount maps cleanly to 1–2 stalks/spears, lead with the
    // count unit cooks actually use instead of a quarter-snapped bunch fraction.
    final countLedLabel = _produceCountLedLabelIfApplicable(
      exactCount: exactCount,
      conversion: conversion,
    );
    if (countLedLabel != null) {
      return countLedLabel;
    }

    final bunchFraction = _roundDiscreteCount(amount);
    final bunchLabel = formatFraction(bunchFraction);
    final unitLabel = _pluralizeUnit('bunch', bunchFraction);

    final approxCount = exactCount.ceil();
    final countHint = approxCount <= 1
        ? conversion.countUnitSingular
        : '~$approxCount ${conversion.countUnitPlural}';

    return '$bunchLabel $unitLabel $ingredientName ($countHint)';
  }

  /// Prefer stalk/spear count when [exactCount] is reliably 1 or 2 whole units.
  String? _produceCountLedLabelIfApplicable({
    required double exactCount,
    required _ProduceConversion conversion,
  }) {
    const tolerance = 0.05;
    final rounded = exactCount.round();
    if (rounded < 1 || rounded > 2) return null;
    if ((exactCount - rounded).abs() > tolerance) return null;

    if (rounded == 1) {
      return '1 ${conversion.countUnitSingular}';
    }
    return '$rounded ${conversion.countUnitPlural}';
  }

  /// Spoonacular often sends spring onions as `piece` counts, not `bunch`.
  /// Prefer a practical stalk label over quarter-snapped fractions.
  String? _producePieceStalkLabelIfApplicable(
    double amount,
    String unit,
    String ingredientName,
  ) {
    if (amount <= 0 || amount >= 1) return null;

    final conversion = _produceConversionFor(ingredientName);
    if (conversion == null || !_usesStalkStyleConversion(conversion)) return null;

    final unitSingular = _singularUnit(unit.toLowerCase());
    if (!_isPieceLikeProduceUnit(unitSingular)) return null;

    // Typical scaled recipe fractions of one onion → one usable stalk.
    if (amount < 0.12 || amount > 0.67) return null;

    final stalk = '1 ${conversion.countUnitSingular}';
    final prep = _actionPrepFromIngredientName(ingredientName);
    if (prep.isEmpty) return stalk;
    return '$stalk, $prep';
  }

  bool _usesStalkStyleConversion(_ProduceConversion conversion) {
    final singular = conversion.countUnitSingular.toLowerCase();
    return singular.contains('stalk') || singular.contains('scallion');
  }

  String _actionPrepFromIngredientName(String ingredientName) {
    const actionWords = {
      'sliced',
      'chopped',
      'diced',
      'minced',
      'grated',
      'shredded',
    };
    final found = <String>[];
    for (final word in ingredientName.split(RegExp(r'\s+'))) {
      final lower = word.toLowerCase();
      if (actionWords.contains(lower) && !found.contains(lower)) {
        found.add(lower);
      }
    }
    return found.join(', ');
  }

  bool _isPieceLikeProduceUnit(String unitSingular) {
    return _wholeCountUnits.contains(unitSingular) ||
        unitSingular == 'stalk' ||
        unitSingular == 'scallion';
  }

  String? _wholeCountRangeLabelIfApplicable(
    double amount,
    String unit,
    String ingredientName,
    IngredientDisplayCategory category,
  ) {
    if (category != IngredientDisplayCategory.count) return null;
    if (amount <= 0) return null;
    if (amount == amount.roundToDouble()) return null;

    final lowerUnit = unit.toLowerCase();
    if (lowerUnit == 'clove' || lowerUnit == 'cloves') return null;

    final lowerName = ingredientName.toLowerCase();
    final isEgg = lowerUnit == 'egg' ||
        lowerUnit == 'eggs' ||
        lowerName.contains('egg');

    if (!isEgg && !_wholeCountUnits.contains(lowerUnit)) return null;

    final low = amount.floor();
    final high = amount.ceil();
    if (low <= 0) return null;

    final unitSingular = isEgg
        ? 'egg'
        : _singularUnit(unit.isEmpty ? 'piece' : unit);
    final unitPlural = isEgg ? 'eggs' : _pluralizeUnit(unitSingular, 2);

    if (high - amount < 0.2) {
      return '$high $unitPlural';
    }
    if (amount - low < 0.2) {
      return '$low ${low == 1 ? unitSingular : unitPlural}';
    }

    return '$low–$high $unitPlural';
  }

  String _appendNameForRange(String rangeLabel, String ingredientName) {
    final trimmed = ingredientName.trim();
    if (trimmed.isEmpty) return rangeLabel;

    final lower = trimmed.toLowerCase();
    if (lower == 'egg' || lower == 'eggs') return rangeLabel;

    if (rangeLabel.endsWith('eggs') && lower.startsWith('eggs')) {
      final extra = trimmed.substring(4).trim();
      if (extra.isEmpty) return rangeLabel;
      return '$rangeLabel $extra';
    }

    if (rangeLabel.endsWith('eggs') && lower.startsWith('egg ')) {
      return '$rangeLabel ${trimmed.substring(4).trim()}';
    }

    return '$rangeLabel $trimmed';
  }

  _ProduceConversion? _produceConversionFor(String ingredientName) {
    final normalized = ingredientName.trim().toLowerCase();
    if (_produceConversions.containsKey(normalized)) {
      return _produceConversions[normalized];
    }

    for (final entry in _produceConversions.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  bool _unitsMatch(String unit, String expected) {
    return _singularUnit(unit).toLowerCase() ==
        _singularUnit(expected).toLowerCase();
  }

  IngredientDisplayCategory _categoryFor(String ingredientName, String unit) {
    final lowerUnit = unit.toLowerCase();

    if (_isPreciseIngredient(ingredientName)) {
      return IngredientDisplayCategory.precise;
    }

    if (_isBakingIngredient(ingredientName) && _isVolumeUnit(unit)) {
      return IngredientDisplayCategory.baking;
    }
    if (_isSeasoning(ingredientName) && _isVolumeUnit(unit)) {
      return IngredientDisplayCategory.seasoning;
    }
    if (_produceConversionFor(ingredientName) != null &&
        _discreteCountUnits.contains(lowerUnit)) {
      return IngredientDisplayCategory.produce;
    }
    if (_isWeightUnit(unit)) {
      return IngredientDisplayCategory.weight;
    }
    if (_wholeCountUnits.contains(lowerUnit) || unit.isEmpty) {
      return IngredientDisplayCategory.count;
    }
    if (_discreteCountUnits.contains(lowerUnit)) {
      return IngredientDisplayCategory.produce;
    }
    if (_isLiquid(ingredientName, unit)) {
      return IngredientDisplayCategory.liquid;
    }
    if (_isVolumeUnit(unit)) {
      return IngredientDisplayCategory.liquid;
    }
    return IngredientDisplayCategory.general;
  }

  bool _isLiquid(String ingredientName, String unit) {
    if (_isVolumeUnit(unit)) {
      final lowerName = ingredientName.toLowerCase();
      return _liquidNameHints.any(lowerName.contains);
    }
    return false;
  }

  double _roundForDisplay(
    double amount,
    String unit, {
    required IngredientDisplayCategory category,
  }) {
    if (amount <= 0) return 0;

    final lowerUnit = unit.toLowerCase();

    switch (category) {
      case IngredientDisplayCategory.precise:
        return amount;
      case IngredientDisplayCategory.baking:
        if (_isVolumeUnit(unit)) {
          return _roundBakingPrecisionTsp(amount);
        }
        return _roundVolume(amount, fine: true);
      case IngredientDisplayCategory.seasoning:
        if (_isVolumeUnit(unit)) {
          return _roundFineSeasoningTsp(amount);
        }
        return _roundVolume(amount, fine: true);
      case IngredientDisplayCategory.liquid:
        if (_amountInTeaspoons(amount, unit) != null && amount > 0) {
          final rounded = _roundVolume(amount, fine: false);
          if (rounded == 0) return _eighthTsp;
        }
        return _roundVolume(amount, fine: false);
      case IngredientDisplayCategory.produce:
        if (_discreteCountUnits.contains(lowerUnit)) {
          return _roundDiscreteCount(amount);
        }
        return _roundGeneral(amount);
      case IngredientDisplayCategory.count:
        final rounded = amount.roundToDouble();
        if (amount > 0 && rounded == 0) return 1;
        return rounded;
      case IngredientDisplayCategory.weight:
        return _roundWeight(amount, unit);
      case IngredientDisplayCategory.general:
        if (_isVolumeUnit(unit)) {
          return _roundVolume(amount, fine: false);
        }
        if (_discreteCountUnits.contains(lowerUnit)) {
          return _roundDiscreteCount(amount);
        }
        if (_wholeCountUnits.contains(lowerUnit)) {
          return amount.roundToDouble();
        }
        return _roundGeneral(amount);
    }
  }

  /// Exact display for therapeutic/supplement ingredients (no cooking rounding).
  String _formatPreciseAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    if (amount < 1) {
      return amount.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    }
    if (amount < 10) {
      return amount.toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '');
    }
    return amount.round().toString();
  }

  bool _isPreciseIngredient(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();
    return _preciseIngredientHints.any(lowerName.contains);
  }

  /// Fine dry seasoning bands (tsp) for display rounding.
  double _roundFineSeasoningTsp(double amount) {
    if (amount < _pinchMaxTsp) return amount;
    if (amount < 0.20) return _eighthTsp;
    if (amount < 0.30) return 0.25;
    if (amount < 0.40) return 1 / 3;
    if (amount < 0.60) return 0.5;
    if (amount < 1) return _snapToStep(amount, step: 0.25);
    return _roundVolume(amount, fine: true);
  }

  /// Conservative baking precision bands — avoid rounding up aggressively.
  double _roundBakingPrecisionTsp(double amount) {
    if (amount < 0.08) return amount;
    if (amount < 0.25) return _eighthTsp;
    if (amount < 0.40) return 0.25;
    if (amount < 1) return _snapToStep(amount, step: _eighthTsp);
    return _roundVolume(amount, fine: true);
  }

  double _roundVolume(double amount, {required bool fine}) {
    if (amount < 1) {
      return _snapToStep(amount, step: fine ? _eighthTsp : 0.25);
    }
    if (amount < 4) {
      return _snapToStep(amount, step: 0.25);
    }
    return _snapToStep(amount, step: 0.5);
  }

  double _roundDiscreteCount(double amount) {
    if (amount < 1) {
      return _snapToStep(amount, step: 0.25);
    }
    if (amount < 4) {
      return _snapToStep(amount, step: 0.5);
    }
    return amount.roundToDouble();
  }

  double _roundWeight(double amount, String unit) {
    final singular = _singularUnit(unit.toLowerCase());

    if (singular == 'ounce' && amount > 0 && amount < 16) {
      return _snapToStep(amount, step: 0.5);
    }
    if (singular == 'gram' || singular == 'g') {
      if (amount < 10) return amount.roundToDouble();
    }
    if (amount >= 100) {
      return amount.roundToDouble();
    }
    if (amount >= 10) {
      return (amount * 10).round() / 10;
    }
    return _snapToStep(amount, step: 0.1);
  }

  double _roundGeneral(double amount) {
    if (amount < 1) {
      return _snapToStep(amount, step: 0.25);
    }
    if (amount < 4) {
      return _snapToStep(amount, step: 0.5);
    }
    return amount.roundToDouble();
  }

  double _snapToStep(double amount, {required double step}) {
    if (step <= 0) return amount;
    return (amount / step).round() * step;
  }

  _ConvertedMeasurement _applyDisplayUnitConversion(double amount, String unit) {
    final lowerUnit = unit.toLowerCase();

    if ((lowerUnit == 'teaspoon' ||
            lowerUnit == 'teaspoons' ||
            lowerUnit == 'tsp' ||
            lowerUnit == 'tsp.' ||
            lowerUnit == 'tsps' ||
            lowerUnit == 'ts') &&
        amount >= 3) {
      final tbspAmount = amount / 3;
      return _ConvertedMeasurement(
        tbspAmount,
        tbspAmount == 1 ? 'tablespoon' : 'tablespoons',
      );
    }

    if ((lowerUnit == 'tablespoon' ||
            lowerUnit == 'tablespoons' ||
            lowerUnit == 'tbsp' ||
            lowerUnit == 'tbsp.' ||
            lowerUnit == 'tbs' ||
            lowerUnit == 'tbs.' ||
            lowerUnit == 'tb' ||
            lowerUnit == 'tbl' ||
            lowerUnit == 'tbls' ||
            lowerUnit == 'tblsp') &&
        amount >= 16) {
      final cupAmount = amount / 16;
      return _ConvertedMeasurement(
        cupAmount,
        cupAmount == 1 ? 'cup' : 'cups',
      );
    }

    if ((lowerUnit == 'tablespoon' ||
            lowerUnit == 'tablespoons' ||
            lowerUnit == 'tbsp' ||
            lowerUnit == 'tbsp.' ||
            lowerUnit == 'tbs' ||
            lowerUnit == 'tbs.' ||
            lowerUnit == 'tb' ||
            lowerUnit == 'tbl' ||
            lowerUnit == 'tbls' ||
            lowerUnit == 'tblsp') &&
        amount < 1 &&
        amount > 0) {
      final tspAmount = amount * 3;
      return _ConvertedMeasurement(
        tspAmount,
        tspAmount == 1 ? 'teaspoon' : 'teaspoons',
      );
    }

    if ((lowerUnit == 'gram' || lowerUnit == 'grams' || lowerUnit == 'g') &&
        amount >= 1000) {
      // US-facing app: prefer pounds over kilograms for large gram amounts.
      final lbAmount = amount / 453.59237;
      return _ConvertedMeasurement(
        lbAmount,
        lbAmount == 1 ? 'pound' : 'pounds',
      );
    }

    if ((lowerUnit == 'ounce' || lowerUnit == 'ounces' || lowerUnit == 'oz') &&
        amount >= 16) {
      final lbAmount = amount / 16;
      return _ConvertedMeasurement(
        lbAmount,
        lbAmount == 1 ? 'pound' : 'pounds',
      );
    }

    if ((lowerUnit == 'ounce' || lowerUnit == 'ounces' || lowerUnit == 'oz') &&
        amount > 0 &&
        amount < 1) {
      final gramAmount = amount * 28.3495;
      return _ConvertedMeasurement(gramAmount, 'g');
    }

    if ((lowerUnit == 'pound' ||
            lowerUnit == 'pounds' ||
            lowerUnit == 'lb' ||
            lowerUnit == 'lbs') &&
        amount > 0 &&
        amount < 1) {
      final ozAmount = amount * 16;
      return _ConvertedMeasurement(
        ozAmount,
        ozAmount == 1 ? 'ounce' : 'ounces',
      );
    }

    // Spoonacular often returns metric kg; US users prefer g / lb.
    // < 1 kg → grams (0.1 kg → 100 g); ≥ 1 kg → pounds.
    if (lowerUnit == 'kg' ||
        lowerUnit == 'kilogram' ||
        lowerUnit == 'kilograms') {
      if (amount > 0 && amount < 1) {
        final gramAmount = amount * 1000;
        return _ConvertedMeasurement(
          gramAmount,
          gramAmount == 1 ? 'gram' : 'grams',
        );
      }
      if (amount >= 1) {
        final lbAmount = amount * 2.2046226;
        return _ConvertedMeasurement(
          lbAmount,
          lbAmount == 1 ? 'pound' : 'pounds',
        );
      }
    }

    if ((lowerUnit == 'cup' || lowerUnit == 'cups') &&
        amount > 0 &&
        amount < 0.125) {
      final tspAmount = amount * 48;
      return _ConvertedMeasurement(
        tspAmount,
        tspAmount == 1 ? 'teaspoon' : 'teaspoons',
      );
    }

    if ((lowerUnit == 'milliliter' ||
            lowerUnit == 'milliliters' ||
            lowerUnit == 'ml') &&
        amount >= 1000) {
      final lAmount = amount / 1000;
      return _ConvertedMeasurement(
        lAmount,
        lAmount == 1 ? 'liter' : 'liters',
      );
    }

    return _ConvertedMeasurement(amount, unit);
  }

  /// Formats a display-rounded amount as a kitchen fraction string.
  String formatFraction(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }

    const tolerance = 0.02;
    final whole = amount.floor();
    final fractional = amount - whole;

    String? fractionLabel;
    if ((fractional - 0.125).abs() < tolerance) {
      fractionLabel = '1/8';
    } else if ((fractional - 0.25).abs() < tolerance) {
      fractionLabel = '1/4';
    } else if ((fractional - 0.333).abs() < tolerance ||
        (fractional - 1 / 3).abs() < tolerance) {
      fractionLabel = '1/3';
    } else if ((fractional - 0.375).abs() < tolerance) {
      fractionLabel = '3/8';
    } else if ((fractional - 0.5).abs() < tolerance) {
      fractionLabel = '1/2';
    } else if ((fractional - 0.625).abs() < tolerance) {
      fractionLabel = '5/8';
    } else if ((fractional - 0.667).abs() < tolerance ||
        (fractional - 2 / 3).abs() < tolerance) {
      fractionLabel = '2/3';
    } else if ((fractional - 0.75).abs() < tolerance) {
      fractionLabel = '3/4';
    } else if ((fractional - 0.875).abs() < tolerance) {
      fractionLabel = '7/8';
    }

    if (fractionLabel == null) {
      if (amount < 1) {
        return amount.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      }
      if (amount < 10) {
        return amount.toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '');
      }
      return amount.round().toString();
    }

    if (whole == 0) return fractionLabel;
    return '$whole $fractionLabel';
  }

  String _pluralizeUnit(String unit, double amount) {
    if (unit.isEmpty) return '';

    final singularUnit = _singularUnit(unit);
    if (amount <= 1.0) return singularUnit;

    switch (singularUnit) {
      case 'cup':
        return 'cups';
      case 'tablespoon':
        return 'tablespoons';
      case 'teaspoon':
        return 'teaspoons';
      case 'ounce':
        return 'ounces';
      case 'pound':
        return 'pounds';
      case 'gram':
        return 'grams';
      case 'kilogram':
        return 'kilograms';
      case 'liter':
        return 'liters';
      case 'milliliter':
        return 'milliliters';
      case 'serving':
        return 'servings';
      case 'clove':
        return 'cloves';
      case 'sprig':
        return 'sprigs';
      case 'slice':
        return 'slices';
      case 'piece':
        return 'pieces';
      case 'packet':
        return 'packets';
      case 'bunch':
        return 'bunches';
      case 'stalk':
        return 'stalks';
      case 'egg':
        return 'eggs';
      case 'tsp':
      case 'tbsp':
      case 'oz':
      case 'g':
      case 'kg':
      case 'ml':
      case 'l':
      case 'lb':
      case 'lbs':
        return singularUnit;
      default:
        return unit;
    }
  }

  String _singularUnit(String unit) {
    switch (unit.toLowerCase()) {
      case 'cups':
        return 'cup';
      case 'tablespoons':
      case 'tablespoon':
      case 'tbsp':
      case 'tbsp.':
      case 'tbsps':
      case 'tbs':
      case 'tbs.':
      case 'tb':
      case 'tb.':
      case 'tbl':
      case 'tbls':
      case 'tblsp':
        return 'tablespoon';
      case 'teaspoons':
      case 'teaspoon':
      case 'tsp':
      case 'tsp.':
      case 'tsps':
      case 'ts':
        return 'teaspoon';
      case 'ounces':
      case 'oz':
        return unit.toLowerCase() == 'oz' ? 'oz' : 'ounce';
      case 'pounds':
      case 'lbs':
      case 'lb':
        return unit.toLowerCase() == 'lb' || unit.toLowerCase() == 'lbs'
            ? unit.toLowerCase()
            : 'pound';
      case 'grams':
      case 'g':
        return unit.toLowerCase() == 'g' ? 'g' : 'gram';
      case 'kilograms':
      case 'kg':
        return unit.toLowerCase() == 'kg' ? 'kg' : 'kilogram';
      case 'liters':
      case 'l':
        return unit.toLowerCase() == 'l' ? 'l' : 'liter';
      case 'milliliters':
      case 'ml':
        return unit.toLowerCase() == 'ml' ? 'ml' : 'milliliter';
      case 'servings':
        return 'serving';
      case 'cloves':
        return 'clove';
      case 'sprigs':
        return 'sprig';
      case 'slices':
        return 'slice';
      case 'pieces':
        return 'piece';
      case 'packets':
        return 'packet';
      case 'bunches':
        return 'bunch';
      case 'stalks':
        return 'stalk';
      case 'eggs':
        return 'egg';
      default:
        return unit;
    }
  }

  bool _isVolumeUnit(String unit) => _volumeUnits.contains(unit.toLowerCase());

  bool _isWeightUnit(String unit) => _weightUnits.contains(unit.toLowerCase());

  /// Cleans Spoonacular display junk: `spoon` units, `spoon salt` names,
  /// and liquids labeled as `pieces` / `some`.
  ({double amount, String unit, String name}) _sanitizeSpoonacularDisplayInput({
    required double amount,
    required String unit,
    required String ingredientName,
  }) {
    var cleanedUnit = unit.trim();
    var cleanedName = ingredientName.trim();

    // Strip orphan punctuation Spoonacular sometimes leaves behind (e.g.
    // "garlic - &" from "garlic – peeled & chopped"); word-boundary only so
    // "half-and-half" and "salt & pepper" are untouched.
    cleanedName = cleanedName
        .replaceAll(RegExp(r'(^|\s)[-–—](\s|$)'), ' ')
        .replaceAll(RegExp(r'^&\s*'), '')
        .replaceAll(RegExp(r'\s*&$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Spoonacular sometimes orders liquid names as "juice of lemon" instead
    // of "lemon juice" — normalize to natural English before formatting.
    final juiceOfMatch = _juiceOfPattern.firstMatch(cleanedName);
    if (juiceOfMatch != null) {
      final fruit = juiceOfMatch.group(1)!.trim();
      if (fruit.isNotEmpty) {
        cleanedName = '$fruit juice';
      }
    }

    final spoonNamePrefix = RegExp(r'^spoons?\s+', caseSensitive: false);
    if (spoonNamePrefix.hasMatch(cleanedName)) {
      cleanedName = cleanedName.replaceFirst(spoonNamePrefix, '').trim();
      final unitLower = cleanedUnit.toLowerCase();
      if (unitLower.isEmpty || unitLower == 'spoon' || unitLower == 'spoons') {
        cleanedUnit = _inferSpoonVolumeUnit(cleanedName);
      }
    }

    cleanedUnit = _normalizeVolumeAbbreviation(cleanedUnit);

    final unitLower = cleanedUnit.toLowerCase();
    if (unitLower == 'spoon' || unitLower == 'spoons') {
      cleanedUnit = _inferSpoonVolumeUnit(cleanedName);
    }

    // "some oil" / "pieces oil" — not real kitchen units for liquids.
    if (_nameLooksLikeLiquid(cleanedName) &&
        (unitLower == 'piece' ||
            unitLower == 'pieces' ||
            unitLower == 'some' ||
            unitLower == 'serving' ||
            unitLower == 'servings')) {
      cleanedUnit = 'tablespoon';
    }

    return (amount: amount, unit: cleanedUnit, name: cleanedName);
  }

  /// Maps Spoonacular shorthand (Tbs, tbsp, tsp, …) to full unit names.
  String _normalizeVolumeAbbreviation(String unit) {
    switch (unit.toLowerCase().trim()) {
      case 'tbs':
      case 'tbs.':
      case 'tb':
      case 'tb.':
      case 'tbl':
      case 'tbls':
      case 'tblsp':
      case 'tbsp':
      case 'tbsp.':
      case 'tbsps':
        return 'tablespoon';
      case 'tsp':
      case 'tsp.':
      case 'tsps':
      case 'ts':
        return 'teaspoon';
      default:
        return unit;
    }
  }

  String _inferSpoonVolumeUnit(String ingredientName) {
    final lower = ingredientName.toLowerCase();
    if (lower.contains('butter') ||
        lower.contains('ghee') ||
        lower.contains('oil') ||
        lower.contains('margarine')) {
      return 'tablespoon';
    }
    return 'teaspoon';
  }

  bool _nameContainsSpoonWord(String ingredientName) {
    return RegExp(r'\bspoons?\b', caseSensitive: false)
        .hasMatch(ingredientName);
  }

  bool _nameLooksLikeLiquid(String ingredientName) {
    final lower = ingredientName.toLowerCase();
    return _liquidNameHints.any(lower.contains);
  }

  /// Prefer singular food names when the displayed amount is ~1.
  String _agreeIngredientName(String name, double amount, String unit) {
    if (name.isEmpty) return name;
    if (amount <= 0) return name;

    // Weight / volume lines keep the Spoonacular noun as-is
    // ("100 grams spinach" should not become "spinaches").
    final unitLower = unit.toLowerCase();
    if (_isWeightUnit(unitLower) || _isVolumeUnit(unitLower)) {
      return name;
    }

    final approxOne = amount > 0.5 && amount < 1.5;
    if (!approxOne) return name;
    return _singularizeFoodName(name);
  }

  String _singularizeFoodName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;

    final parts = trimmed.split(RegExp(r'\s+'));
    final last = parts.last;
    final singularLast = _singularizeWord(last);
    if (singularLast == last) return trimmed;
    parts[parts.length - 1] = _matchCapitalization(last, singularLast);
    return parts.join(' ');
  }

  String _singularizeWord(String word) {
    final lower = word.toLowerCase();
    const irregular = <String, String>{
      'chillies': 'chilli',
      'chilies': 'chili',
      'tomatoes': 'tomato',
      'potatoes': 'potato',
      'leaves': 'leaf',
      'loaves': 'loaf',
      'cloves': 'clove',
      'bunches': 'bunch',
      'stalks': 'stalk',
      'sprigs': 'sprig',
      'slices': 'slice',
      'pieces': 'piece',
      'eggs': 'egg',
    };
    if (irregular.containsKey(lower)) return irregular[lower]!;

    if (lower.endsWith('ies') && lower.length > 4) {
      return '${lower.substring(0, lower.length - 3)}y';
    }
    if (lower.endsWith('oes') && lower.length > 4) {
      return lower.substring(0, lower.length - 2);
    }
    if (lower.endsWith('sses') ||
        lower.endsWith('ss') ||
        lower.endsWith('us') ||
        lower.endsWith('is')) {
      return lower;
    }
    if (lower.endsWith('s') && lower.length > 3) {
      return lower.substring(0, lower.length - 1);
    }
    return lower;
  }

  String _matchCapitalization(String original, String replacement) {
    if (original.isEmpty) return replacement;
    if (original == original.toUpperCase()) return replacement.toUpperCase();
    if (original[0] == original[0].toUpperCase()) {
      if (replacement.isEmpty) return replacement;
      return '${replacement[0].toUpperCase()}${replacement.substring(1)}';
    }
    return replacement;
  }

  bool _isSeasoning(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();
    const seasonings = [
      'salt',
      'pepper',
      'paprika',
      'cumin',
      'oregano',
      'basil',
      'thyme',
      'rosemary',
      'cinnamon',
      'nutmeg',
      'ginger',
      'turmeric',
      'chili',
      'garlic powder',
      'onion powder',
      'bay leaf',
      'parsley',
      'cilantro',
      'dill',
      'sage',
      'marjoram',
      'tarragon',
      'mint',
      'cardamom',
      'cloves',
      'allspice',
      'fennel',
      'coriander',
      'mustard seed',
      'celery seed',
      'caraway',
      'anise',
      'vanilla',
      'seasoning',
      'spice',
      'herb',
      'dried',
      'ground',
    ];
    return seasonings.any(lowerName.contains);
  }

  bool _isBakingIngredient(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();
    const baking = [
      'baking soda',
      'baking powder',
      'yeast',
      'cornstarch',
      'cream of tartar',
    ];
    return baking.any(lowerName.contains);
  }

  String _joinLine(List<String> parts) {
    return parts.where((part) => part.isNotEmpty).join(' ').trim();
  }
}

class _ConvertedMeasurement {
  final double amount;
  final String unit;

  const _ConvertedMeasurement(this.amount, this.unit);
}

class _ProduceConversion {
  final String sourceUnit;
  final int countPerSource;
  final String countUnitSingular;
  final String countUnitPlural;

  const _ProduceConversion({
    required this.sourceUnit,
    required this.countPerSource,
    required this.countUnitSingular,
    required this.countUnitPlural,
  });
}

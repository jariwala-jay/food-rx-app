import 'package:flutter_app/features/recipes/models/nutrition.dart';
import 'package:flutter_app/features/recipes/utils/recipe_image_urls.dart';

class Recipe {
  final int id;
  final String title;
  final String image;
  final int readyInMinutes;
  final int servings;
  final String sourceUrl;
  final String summary;
  final List<String> cuisines;
  final List<String> dishTypes;
  final List<String> diets;
  final List<RecipeIngredient> extendedIngredients;
  final List<RecipeInstruction> analyzedInstructions;
  final bool vegetarian;
  final bool vegan;
  final bool glutenFree;
  final bool dairyFree;
  final bool veryHealthy;
  final bool cheap;
  final bool veryPopular;
  final bool sustainable;
  final bool lowFodmap;
  final int weightWatcherSmartPoints;
  final String gaps;
  final double pricePerServing;
  final int aggregateLikes;
  final double healthScore;
  final String creditsText;
  final String license;
  final String sourceName;
  final double spoonacularScore;
  final String spoonacularSourceUrl;
  final Nutrition? nutrition;

  // Spoonacular's ingredient matching data
  final int? missedIngredientCount;
  final int? usedIngredientCount;
  final List<RecipeIngredient> missedIngredients;
  final List<RecipeIngredient> usedIngredients;

  // Custom metadata for our app
  final List<String> pantryItemsUsed;
  final List<String> expiringItemsUsed;
  final bool isDashCompliant;
  final bool isMyPlateCompliant;
  final DateTime? savedAt;
  final bool isSaved;

  Recipe({
    required this.id,
    required this.title,
    required this.image,
    required this.readyInMinutes,
    required this.servings,
    required this.sourceUrl,
    required this.summary,
    required this.cuisines,
    required this.dishTypes,
    required this.diets,
    required this.extendedIngredients,
    required this.analyzedInstructions,
    required this.vegetarian,
    required this.vegan,
    required this.glutenFree,
    required this.dairyFree,
    required this.veryHealthy,
    required this.cheap,
    required this.veryPopular,
    required this.sustainable,
    required this.lowFodmap,
    required this.weightWatcherSmartPoints,
    required this.gaps,
    required this.pricePerServing,
    required this.aggregateLikes,
    required this.healthScore,
    required this.creditsText,
    required this.license,
    required this.sourceName,
    required this.spoonacularScore,
    required this.spoonacularSourceUrl,
    this.nutrition,
    this.missedIngredientCount,
    this.usedIngredientCount,
    this.missedIngredients = const [],
    this.usedIngredients = const [],
    this.pantryItemsUsed = const [],
    this.expiringItemsUsed = const [],
    this.isDashCompliant = false,
    this.isMyPlateCompliant = false,
    this.savedAt,
    this.isSaved = false,
  });

  /// Builds a usable image URL from Spoonacular search/detail payloads.
  static String resolveImageUrl(Map<String, dynamic> json) =>
      RecipeImageUrls.resolveFromJson(json);

  /// Whether we can attempt to load a recipe photo (Spoonacular CDN fallbacks).
  bool get hasRecipeImage =>
      RecipeImageUrls.hasResolvableImage(id: id, image: image);

  /// True when the recipe has at least one real written cooking step.
  bool get hasCookingInstructions =>
      analyzedInstructions.any((block) => block.cookingSteps.isNotEmpty);

  /// URLs to try when the primary [image] fails to load (jpg/png, CDN + legacy).
  List<String> get imageUrlCandidates => RecipeImageUrls.candidatesFor(
        id: id,
        image: image,
        ingredientImageUrls:
            extendedIngredients.map((e) => e.image).where((u) => u.isNotEmpty),
      );

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      image: resolveImageUrl(json),
      readyInMinutes: json['readyInMinutes'] ?? 0,
      servings: json['servings'] ?? 1,
      sourceUrl: json['sourceUrl'] ?? '',
      summary: json['summary'] ?? '',
      cuisines: List<String>.from(json['cuisines'] ?? []),
      dishTypes: List<String>.from(json['dishTypes'] ?? []),
      diets: List<String>.from(json['diets'] ?? []),
      extendedIngredients: RecipeIngredient.mergeDuplicateLines(
        (json['extendedIngredients'] as List<dynamic>?)
                ?.map((e) => RecipeIngredient.fromJson(e))
                .toList() ??
            [],
      ),
      analyzedInstructions: (json['analyzedInstructions'] as List<dynamic>?)
              ?.map((e) => RecipeInstruction.fromJson(e))
              .toList() ??
          [],
      vegetarian: json['vegetarian'] ?? false,
      vegan: json['vegan'] ?? false,
      glutenFree: json['glutenFree'] ?? false,
      dairyFree: json['dairyFree'] ?? false,
      veryHealthy: json['veryHealthy'] ?? false,
      cheap: json['cheap'] ?? false,
      veryPopular: json['veryPopular'] ?? false,
      sustainable: json['sustainable'] ?? false,
      lowFodmap: json['lowFodmap'] ?? false,
      weightWatcherSmartPoints: json['weightWatcherSmartPoints'] ?? 0,
      gaps: json['gaps'] ?? '',
      pricePerServing: (json['pricePerServing'] ?? 0).toDouble(),
      aggregateLikes: json['aggregateLikes'] ?? 0,
      healthScore: (json['healthScore'] ?? 0).toDouble(),
      creditsText: json['creditsText'] ?? '',
      license: json['license'] ?? '',
      sourceName: json['sourceName'] ?? '',
      spoonacularScore: (json['spoonacularScore'] ?? 0).toDouble(),
      spoonacularSourceUrl: json['spoonacularSourceUrl'] ?? '',
      pantryItemsUsed: List<String>.from(json['pantryItemsUsed'] ?? []),
      expiringItemsUsed: List<String>.from(json['expiringItemsUsed'] ?? []),
      isDashCompliant: json['isDashCompliant'] ?? false,
      isMyPlateCompliant: json['isMyPlateCompliant'] ?? false,
      savedAt: json['savedAt'] != null ? DateTime.parse(json['savedAt']) : null,
      isSaved: json['isSaved'] ?? false,
      nutrition: json['nutrition'] != null
          ? Nutrition.fromJson(json['nutrition'])
          : null,
      missedIngredientCount: json['missedIngredientCount'],
      usedIngredientCount: json['usedIngredientCount'],
      missedIngredients: (json['missedIngredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e))
              .toList() ??
          [],
      usedIngredients: (json['usedIngredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e))
              .toList() ??
          [],
    );
  }

  factory Recipe.fromSpoonacular(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      image: resolveImageUrl(json),
      readyInMinutes: json['readyInMinutes'] ?? 0,
      servings: json['servings'] ?? 1,
      sourceUrl: json['sourceUrl'] ?? '',
      summary: json['summary'] ?? '',
      cuisines: List<String>.from(json['cuisines'] ?? []),
      dishTypes: List<String>.from(json['dishTypes'] ?? []),
      diets: List<String>.from(json['diets'] ?? []),
      extendedIngredients: RecipeIngredient.mergeDuplicateLines(
        (json['extendedIngredients'] as List<dynamic>?)
                ?.map((e) => RecipeIngredient.fromJson(e))
                .toList() ??
            [],
      ),
      analyzedInstructions: (json['analyzedInstructions'] as List<dynamic>?)
              ?.map((e) => RecipeInstruction.fromJson(e))
              .toList() ??
          [],
      vegetarian: json['vegetarian'] ?? false,
      vegan: json['vegan'] ?? false,
      glutenFree: json['glutenFree'] ?? false,
      dairyFree: json['dairyFree'] ?? false,
      veryHealthy: json['veryHealthy'] ?? false,
      cheap: json['cheap'] ?? false,
      veryPopular: json['veryPopular'] ?? false,
      sustainable: json['sustainable'] ?? false,
      lowFodmap: json['lowFodmap'] ?? false,
      weightWatcherSmartPoints: json['weightWatcherSmartPoints'] ?? 0,
      gaps: json['gaps'] ?? '',
      pricePerServing: (json['pricePerServing'] ?? 0).toDouble(),
      aggregateLikes: json['aggregateLikes'] ?? 0,
      healthScore: (json['healthScore'] ?? 0).toDouble(),
      creditsText: json['creditsText'] ?? '',
      license: json['license'] ?? '',
      sourceName: json['sourceName'] ?? '',
      spoonacularScore: (json['spoonacularScore'] ?? 0).toDouble(),
      spoonacularSourceUrl: json['spoonacularSourceUrl'] ?? '',
      nutrition: json['nutrition'] != null
          ? Nutrition.fromJson(json['nutrition'])
          : null,
      missedIngredientCount: json['missedIngredientCount'],
      usedIngredientCount: json['usedIngredientCount'],
      missedIngredients: (json['missedIngredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e))
              .toList() ??
          [],
      usedIngredients: (json['usedIngredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e))
              .toList() ??
          [],
    );
  }

  // Factory method for creating Recipe from complexSearch results
  factory Recipe.fromSearchResult(Map<String, dynamic> json) {
    return Recipe.fromSpoonacular(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'readyInMinutes': readyInMinutes,
      'servings': servings,
      'sourceUrl': sourceUrl,
      'summary': summary,
      'cuisines': cuisines,
      'dishTypes': dishTypes,
      'diets': diets,
      'extendedIngredients':
          extendedIngredients.map((e) => e.toJson()).toList(),
      'analyzedInstructions':
          analyzedInstructions.map((e) => e.toJson()).toList(),
      'vegetarian': vegetarian,
      'vegan': vegan,
      'glutenFree': glutenFree,
      'dairyFree': dairyFree,
      'veryHealthy': veryHealthy,
      'cheap': cheap,
      'veryPopular': veryPopular,
      'sustainable': sustainable,
      'lowFodmap': lowFodmap,
      'weightWatcherSmartPoints': weightWatcherSmartPoints,
      'gaps': gaps,
      'pricePerServing': pricePerServing,
      'aggregateLikes': aggregateLikes,
      'healthScore': healthScore,
      'creditsText': creditsText,
      'license': license,
      'sourceName': sourceName,
      'spoonacularScore': spoonacularScore,
      'spoonacularSourceUrl': spoonacularSourceUrl,
      'pantryItemsUsed': pantryItemsUsed,
      'expiringItemsUsed': expiringItemsUsed,
      'isDashCompliant': isDashCompliant,
      'isMyPlateCompliant': isMyPlateCompliant,
      'savedAt': savedAt?.toIso8601String(),
      'isSaved': isSaved,
      'nutrition': nutrition?.toJson(),
      'missedIngredientCount': missedIngredientCount,
      'usedIngredientCount': usedIngredientCount,
      'missedIngredients': missedIngredients.map((e) => e.toJson()).toList(),
      'usedIngredients': usedIngredients.map((e) => e.toJson()).toList(),
    };
  }

  Recipe copyWith({
    int? id,
    String? title,
    String? image,
    int? readyInMinutes,
    int? servings,
    String? sourceUrl,
    String? summary,
    List<String>? cuisines,
    List<String>? dishTypes,
    List<String>? diets,
    List<RecipeIngredient>? extendedIngredients,
    List<RecipeInstruction>? analyzedInstructions,
    bool? vegetarian,
    bool? vegan,
    bool? glutenFree,
    bool? dairyFree,
    bool? veryHealthy,
    bool? cheap,
    bool? veryPopular,
    bool? sustainable,
    bool? lowFodmap,
    int? weightWatcherSmartPoints,
    String? gaps,
    double? pricePerServing,
    int? aggregateLikes,
    double? healthScore,
    String? creditsText,
    String? license,
    String? sourceName,
    double? spoonacularScore,
    String? spoonacularSourceUrl,
    Nutrition? nutrition,
    int? missedIngredientCount,
    int? usedIngredientCount,
    List<RecipeIngredient>? missedIngredients,
    List<RecipeIngredient>? usedIngredients,
    List<String>? pantryItemsUsed,
    List<String>? expiringItemsUsed,
    bool? isDashCompliant,
    bool? isMyPlateCompliant,
    DateTime? savedAt,
    bool? isSaved,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      image: image ?? this.image,
      readyInMinutes: readyInMinutes ?? this.readyInMinutes,
      servings: servings ?? this.servings,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      summary: summary ?? this.summary,
      cuisines: cuisines ?? this.cuisines,
      dishTypes: dishTypes ?? this.dishTypes,
      diets: diets ?? this.diets,
      extendedIngredients: extendedIngredients ?? this.extendedIngredients,
      analyzedInstructions: analyzedInstructions ?? this.analyzedInstructions,
      vegetarian: vegetarian ?? this.vegetarian,
      vegan: vegan ?? this.vegan,
      glutenFree: glutenFree ?? this.glutenFree,
      dairyFree: dairyFree ?? this.dairyFree,
      veryHealthy: veryHealthy ?? this.veryHealthy,
      cheap: cheap ?? this.cheap,
      veryPopular: veryPopular ?? this.veryPopular,
      sustainable: sustainable ?? this.sustainable,
      lowFodmap: lowFodmap ?? this.lowFodmap,
      weightWatcherSmartPoints:
          weightWatcherSmartPoints ?? this.weightWatcherSmartPoints,
      gaps: gaps ?? this.gaps,
      pricePerServing: pricePerServing ?? this.pricePerServing,
      aggregateLikes: aggregateLikes ?? this.aggregateLikes,
      healthScore: healthScore ?? this.healthScore,
      creditsText: creditsText ?? this.creditsText,
      license: license ?? this.license,
      sourceName: sourceName ?? this.sourceName,
      spoonacularScore: spoonacularScore ?? this.spoonacularScore,
      spoonacularSourceUrl: spoonacularSourceUrl ?? this.spoonacularSourceUrl,
      nutrition: nutrition ?? this.nutrition,
      missedIngredientCount:
          missedIngredientCount ?? this.missedIngredientCount,
      usedIngredientCount: usedIngredientCount ?? this.usedIngredientCount,
      missedIngredients: missedIngredients ?? this.missedIngredients,
      usedIngredients: usedIngredients ?? this.usedIngredients,
      pantryItemsUsed: pantryItemsUsed ?? this.pantryItemsUsed,
      expiringItemsUsed: expiringItemsUsed ?? this.expiringItemsUsed,
      isDashCompliant: isDashCompliant ?? this.isDashCompliant,
      isMyPlateCompliant: isMyPlateCompliant ?? this.isMyPlateCompliant,
      savedAt: savedAt ?? this.savedAt,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  /// Required ingredient lines (excludes optional — matches green/orange badges).
  int get requiredIngredientLineCount =>
      RecipeIngredient.mergeDuplicateLines(extendedIngredients)
          .where((i) => !i.isOptionalIngredient)
          .length;

  int get optionalIngredientLineCount =>
      RecipeIngredient.mergeDuplicateLines(extendedIngredients)
          .where((i) => i.isOptionalIngredient)
          .length;

  /// Shopping-cart style count: missed items excluding optional lines (see [RecipeIngredient.isOptionalIngredient]).
  int get requiredMissedIngredientCount {
    if (missedIngredients.isNotEmpty) {
      return missedIngredients.where((e) => !e.isOptionalIngredient).length;
    }
    return missedIngredientCount ?? 0;
  }
}

class RecipeIngredient {
  final int id;
  final String aisle;
  final String image;
  final String consistency;
  final String name;
  final String nameClean;
  final String original;
  final String originalName;
  final double amount;
  final String unit;
  final List<String> meta;
  final Measures measures;
  final bool isAvailableInPantry;
  final bool isExpiring;

  RecipeIngredient({
    required this.id,
    required this.aisle,
    required this.image,
    required this.consistency,
    required this.name,
    required this.nameClean,
    required this.original,
    required this.originalName,
    required this.amount,
    required this.unit,
    required this.meta,
    required this.measures,
    this.isAvailableInPantry = false,
    this.isExpiring = false,
  });

  static bool _textSuggestsOptional(String s) =>
      s.toLowerCase().contains('optional');

  /// True when Spoonacular marks this line optional (see [original] / [meta]).
  bool get isOptionalIngredient =>
      _textSuggestsOptional(original) ||
      _textSuggestsOptional(originalName) ||
      _textSuggestsOptional(name) ||
      meta.any(_textSuggestsOptional);

  /// Appends a visible `optional` suffix for the ingredients list (from API text).
  String formatDisplayLine(String scaledLine) {
    final built = scaledLine.trim();
    if (!isOptionalIngredient) return built;

    final withoutTag = built
        .replaceAll(RegExp(r',?\s*optional\.?$', caseSensitive: false), '')
        .trim();
    if (withoutTag.toLowerCase().endsWith(' optional')) {
      return withoutTag;
    }
    return '$withoutTag optional';
  }

  /// Key for collapsing identical Spoonacular lines (same name + unit + optional).
  static String duplicateMergeKey(RecipeIngredient ingredient) {
    final name = resolveDisplayName(ingredient.nameClean, ingredient.name)
        .toLowerCase()
        .trim();
    final unit = ingredient.unit.toLowerCase().trim();
    final optional = ingredient.isOptionalIngredient ? '1' : '0';
    return '$name|$unit|$optional';
  }

  /// Collapses identical ingredient lines (same name + unit + optional).
  static List<RecipeIngredient> mergeDuplicateLines(
    List<RecipeIngredient> ingredients,
  ) {
    if (ingredients.length < 2) return List<RecipeIngredient>.from(ingredients);

    final seen = <String>{};
    final unique = <RecipeIngredient>[];

    for (final ingredient in ingredients) {
      final key = duplicateMergeKey(ingredient);
      if (!seen.add(key)) continue;
      unique.add(ingredient);
    }

    return unique;
  }

  /// Best label for display / pantry matching (non-empty [nameClean], else [name]).
  static String resolveDisplayName(String nameClean, String name) {
    final clean = nameClean.trim();
    if (clean.isNotEmpty) {
      return dedupeConsecutiveWords(_stripOrphanPunctuation(clean));
    }
    return dedupeConsecutiveWords(_stripOrphanPunctuation(name.trim()));
  }

  /// Strips orphan punctuation Spoonacular sometimes leaves in `nameClean`
  /// (e.g. `"garlic - &"` from `"garlic – crushed & chopped"`). Runs before
  /// [composeIngredientDisplayName] appends its suffix, since a later
  /// boundary-only pass wouldn't catch the `&` once it's glued to a comma.
  /// Dashes only strip at word boundaries (not `"half-and-half"`); `&` only
  /// at the start/end (not mid-string `"salt & pepper"`).
  static String _stripOrphanPunctuation(String text) {
    return text
        .replaceAll(RegExp(r'(^|\s)[-–—](\s|$)'), ' ')
        .replaceAll(RegExp(r'^&\s*'), '')
        .replaceAll(RegExp(r'\s*&$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Natural reading order for UI (e.g. `basil dried` → `dried basil`).
  static String composeIngredientDisplayName(
    String nameClean,
    String prepDescriptors,
  ) {
    final merged = dedupeConsecutiveWords('$prepDescriptors $nameClean'.trim());
    if (merged.isEmpty) return nameClean.trim();

    const attributeDescriptors = {
      'dried',
      'fresh',
      'ground',
      'whole',
      'large',
      'small',
      'medium',
      'organic',
      'lean',
      'free-range',
    };
    const actionDescriptors = {
      'chopped',
      'diced',
      'sliced',
      'grated',
      'shredded',
      'minced',
    };

    final words = merged.split(RegExp(r'\s+'));
    if (words.length < 2) return merged;

    final attributeWords = <String>[];
    final actionWords = <String>[];
    final nounWords = <String>[];

    for (final word in words) {
      final lower = word.toLowerCase().replaceAll(RegExp(r'[,.]$'), '');
      if (attributeDescriptors.contains(lower)) {
        if (!attributeWords.any((w) => w.toLowerCase() == lower)) {
          attributeWords.add(word);
        }
      } else if (actionDescriptors.contains(lower)) {
        if (!actionWords.any((w) => w.toLowerCase() == lower)) {
          actionWords.add(lower);
        }
      } else if (!attributeWords.any((w) => w.toLowerCase() == lower) &&
          !actionWords.any((w) => w.toLowerCase() == lower)) {
        nounWords.add(word);
      }
    }

    if (nounWords.isEmpty) return merged;

    final namePart = attributeWords.isEmpty
        ? nounWords.join(' ')
        : '${attributeWords.join(' ')} ${nounWords.join(' ')}';

    if (actionWords.isEmpty) {
      return dedupeConsecutiveWords(namePart);
    }
    return dedupeConsecutiveWords('$namePart, ${actionWords.join(', ')}');
  }

  /// Collapses repeated words (e.g. Spoonacular `nameClean`: "celery celery").
  static String dedupeConsecutiveWords(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length <= 1) return text.trim();

    final out = <String>[];
    for (final word in words) {
      if (out.isNotEmpty && out.last.toLowerCase() == word.toLowerCase()) {
        continue;
      }
      out.add(word);
    }
    return out.join(' ');
  }

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    final rawUnit = json['unit'] ?? '';
    final name = (json['name'] ?? '').toString();
    final nameCleanRaw = (json['nameClean'] ?? '').toString();
    final ingredientName = resolveDisplayName(nameCleanRaw, name);

    return RecipeIngredient(
      id: json['id'] ?? 0,
      aisle: json['aisle'] ?? '',
      image: json['image'] ?? '',
      consistency: json['consistency'] ?? '',
      name: name,
      nameClean: ingredientName,
      original: json['original'] ?? '',
      originalName: json['originalName'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      unit: _fixMalformedUnit(rawUnit, ingredientName),
      meta: List<String>.from(json['meta'] ?? []),
      measures: Measures.fromJson(json['measures'] ?? {}),
      isAvailableInPantry: json['isAvailableInPantry'] ?? false,
      isExpiring: json['isExpiring'] ?? false,
    );
  }

  /// Strips ingredient name accidentally embedded in Spoonacular [unit] (e.g. "cups celery").
  static String sanitizeUnit(String unit, String ingredientName) {
    var u = _stripSizeDescriptorFromUnit(unit.trim());
    final name = ingredientName.trim();
    if (u.isEmpty) return '';
    if (name.isEmpty) return u;

    final uLower = u.toLowerCase();
    final nameLower = name.toLowerCase();
    if (uLower == nameLower) return '';

    // Spoonacular often uses bare "spoon" instead of tsp/tbsp.
    if (uLower == 'spoon' || uLower == 'spoons') {
      if (nameLower.contains('butter') ||
          nameLower.contains('ghee') ||
          nameLower.contains('oil') ||
          nameLower.contains('margarine')) {
        return 'tablespoon';
      }
      return 'teaspoon';
    }

    // Normalize common tablespoon abbreviations (Tbs, tbsp, Tb, etc.).
    if (uLower == 'tbs' ||
        uLower == 'tbs.' ||
        uLower == 'tb' ||
        uLower == 'tb.' ||
        uLower == 'tbl' ||
        uLower == 'tbls' ||
        uLower == 'tblsp' ||
        uLower == 'tbsp' ||
        uLower == 'tbsp.' ||
        uLower == 'tbsps') {
      return 'tablespoon';
    }
    if (uLower == 'tsp' ||
        uLower == 'tsp.' ||
        uLower == 'tsps' ||
        uLower == 'ts') {
      return 'teaspoon';
    }

    if (uLower.endsWith(' $nameLower')) {
      return u.substring(0, u.length - name.length).trim();
    }
    if (uLower.startsWith('$nameLower ')) {
      return u.substring(name.length).trim();
    }

    return u
        .replaceAll(
          RegExp('\\b${RegExp.escape(name)}\\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Spoonacular sometimes stores size words in [unit] (e.g. `small` for spring onions).
  static String _stripSizeDescriptorFromUnit(String unit) {
    if (unit.isEmpty) return unit;

    const sizeDescriptors = {'small', 'medium', 'large'};
    var remaining = unit.trim();
    var lower = remaining.toLowerCase();

    while (sizeDescriptors.contains(lower)) {
      return '';
    }

    for (final size in sizeDescriptors) {
      final prefix = '$size ';
      if (lower.startsWith(prefix)) {
        remaining = remaining.substring(size.length).trim();
        lower = remaining.toLowerCase();
        if (sizeDescriptors.contains(lower)) return '';
      }
    }

    return remaining;
  }

  /// Fixes malformed units from Spoonacular API at the source
  static String _fixMalformedUnit(String unit, String ingredientName) {
    // If unit is 'servings' or 'serving', try to convert to a proper unit
    if (unit.toLowerCase() == 'servings' || unit.toLowerCase() == 'serving') {
      // For common ingredients, convert to appropriate units based on typical usage
      final lowerName = ingredientName.toLowerCase();

      if (lowerName.contains('egg')) {
        return 'piece'; // eggs are typically counted as pieces
      } else if (lowerName.contains('cheese') && lowerName.contains('cream')) {
        return 'oz'; // cream cheese is typically measured in ounces
      } else if (lowerName.contains('ham') || lowerName.contains('meat')) {
        return 'oz'; // meat is typically measured in ounces
      } else if (lowerName.contains('butter')) {
        return 'tbsp'; // butter is typically measured in tablespoons
      } else if (lowerName.contains('milk')) {
        return 'cup'; // milk is typically measured in cups
      } else if (lowerName.contains('bread')) {
        return 'slice'; // bread is typically measured in slices
      } else if (lowerName.contains('chicken') &&
          (lowerName.contains('breast') || lowerName.contains('thigh'))) {
        return 'piece'; // chicken pieces are typically counted
      } else {
        return 'piece'; // default to piece for count-based items
      }
    }

    return sanitizeUnit(unit, ingredientName);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'aisle': aisle,
      'image': image,
      'consistency': consistency,
      'name': name,
      'nameClean': nameClean,
      'original': original,
      'originalName': originalName,
      'amount': amount,
      'unit': unit,
      'meta': meta,
      'measures': measures.toJson(),
      'isAvailableInPantry': isAvailableInPantry,
      'isExpiring': isExpiring,
    };
  }

  RecipeIngredient copyWith({
    int? id,
    String? aisle,
    String? image,
    String? consistency,
    String? name,
    String? nameClean,
    String? original,
    String? originalName,
    double? amount,
    String? unit,
    List<String>? meta,
    Measures? measures,
    bool? isAvailableInPantry,
    bool? isExpiring,
  }) {
    return RecipeIngredient(
      id: id ?? this.id,
      aisle: aisle ?? this.aisle,
      image: image ?? this.image,
      consistency: consistency ?? this.consistency,
      name: name ?? this.name,
      nameClean: nameClean ?? this.nameClean,
      original: original ?? this.original,
      originalName: originalName ?? this.originalName,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      meta: meta ?? this.meta,
      measures: measures ?? this.measures,
      isAvailableInPantry: isAvailableInPantry ?? this.isAvailableInPantry,
      isExpiring: isExpiring ?? this.isExpiring,
    );
  }
}

class Measures {
  final Measure us;
  final Measure metric;

  Measures({
    required this.us,
    required this.metric,
  });

  factory Measures.fromJson(Map<String, dynamic> json) {
    return Measures(
      us: Measure.fromJson(json['us'] ?? {}),
      metric: Measure.fromJson(json['metric'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'us': us.toJson(),
      'metric': metric.toJson(),
    };
  }
}

class Measure {
  final double amount;
  final String unitShort;
  final String unitLong;

  Measure({
    required this.amount,
    required this.unitShort,
    required this.unitLong,
  });

  factory Measure.fromJson(Map<String, dynamic> json) {
    return Measure(
      amount: (json['amount'] ?? 0).toDouble(),
      unitShort: json['unitShort'] ?? '',
      unitLong: json['unitLong'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'unitShort': unitShort,
      'unitLong': unitLong,
    };
  }
}

class RecipeInstruction {
  final String name;
  final List<InstructionStep> steps;

  RecipeInstruction({
    required this.name,
    required this.steps,
  });

  factory RecipeInstruction.fromJson(Map<String, dynamic> json) {
    return RecipeInstruction(
      name: json['name'] ?? '',
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => InstructionStep.fromJson(e))
              .toList() ??
          [],
    );
  }

  /// Written cooking steps only (no "Serves 6", "Watch video", etc.).
  List<InstructionStep> get cookingSteps =>
      steps.where((s) => InstructionStep.isCookingStep(s.step)).toList();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'steps': steps.map((e) => e.toJson()).toList(),
    };
  }
}

class InstructionStep {
  final int number;
  final String step;
  final List<StepIngredient> ingredients;
  final List<StepEquipment> equipment;
  final StepLength? length;

  InstructionStep({
    required this.number,
    required this.step,
    required this.ingredients,
    required this.equipment,
    this.length,
  });

  /// True when [text] is a real cooking step (not serving/video placeholders).
  static bool isCookingStep(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (isServingMetadata(t) || isVideoPlaceholder(t)) return false;
    // Drop very short lines with no amounts/temps (usually junk metadata).
    if (t.length < 12 && !RegExp(r'\d').hasMatch(t)) return false;
    return true;
  }

  /// True when [text] is yield/serving metadata, not a cooking step.
  static bool isServingMetadata(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;

    final patterns = [
      RegExp(r'^serves?\s*:?\s*\d+', caseSensitive: false),
      RegExp(r'^serve\s+\d+', caseSensitive: false),
      RegExp(r'^yield\s*:?\s*\d+', caseSensitive: false),
      RegExp(r'^makes?\s+\d+\s+servings?', caseSensitive: false),
      RegExp(r'^\d+\s+servings?\s*\.?$', caseSensitive: false),
      RegExp(r'^servings?\s*:?\s*\d+', caseSensitive: false),
    ];
    return patterns.any((p) => p.hasMatch(t));
  }

  /// Spoonacular sometimes returns only "Watch video" / "Whatch video" as instructions.
  static bool isVideoPlaceholder(String text) {
    final t =
        text.trim().toLowerCase().replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (t.isEmpty) return false;

    final patterns = [
      RegExp(r'^(whatch|watch|see|view)\s+(the\s+)?video'),
      RegExp(r'^(whatch|watch)\s+(the\s+)?recipe'),
      RegExp(r'^video\s+(only|instructions?)?\.?$'),
      RegExp(r'^click\s+.*\bvideo\b'),
      RegExp(r'^for\s+(the\s+)?(full\s+)?instructions.*\bvideo\b'),
      RegExp(r'^instructions?\s+(in\s+)?(the\s+)?video'),
    ];
    return patterns.any((p) => p.hasMatch(t));
  }

  factory InstructionStep.fromJson(Map<String, dynamic> json) {
    return InstructionStep(
      number: json['number'] ?? 0,
      step: json['step'] ?? '',
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => StepIngredient.fromJson(e))
              .toList() ??
          [],
      equipment: (json['equipment'] as List<dynamic>?)
              ?.map((e) => StepEquipment.fromJson(e))
              .toList() ??
          [],
      length:
          json['length'] != null ? StepLength.fromJson(json['length']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'step': step,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'equipment': equipment.map((e) => e.toJson()).toList(),
      'length': length?.toJson(),
    };
  }
}

class StepIngredient {
  final int id;
  final String name;
  final String localizedName;
  final String image;

  StepIngredient({
    required this.id,
    required this.name,
    required this.localizedName,
    required this.image,
  });

  factory StepIngredient.fromJson(Map<String, dynamic> json) {
    return StepIngredient(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      localizedName: json['localizedName'] ?? '',
      image: json['image'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'localizedName': localizedName,
      'image': image,
    };
  }
}

class StepEquipment {
  final int id;
  final String name;
  final String localizedName;
  final String image;

  StepEquipment({
    required this.id,
    required this.name,
    required this.localizedName,
    required this.image,
  });

  factory StepEquipment.fromJson(Map<String, dynamic> json) {
    return StepEquipment(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      localizedName: json['localizedName'] ?? '',
      image: json['image'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'localizedName': localizedName,
      'image': image,
    };
  }
}

class StepLength {
  final int number;
  final String unit;

  StepLength({
    required this.number,
    required this.unit,
  });

  factory StepLength.fromJson(Map<String, dynamic> json) {
    return StepLength(
      number: json['number'] ?? 0,
      unit: json['unit'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'unit': unit,
    };
  }
}

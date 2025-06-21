import 'package:flutter_app/features/recipes/models/nutrition.dart';

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

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      image: json['image'] ?? '',
      readyInMinutes: json['readyInMinutes'] ?? 0,
      servings: json['servings'] ?? 1,
      sourceUrl: json['sourceUrl'] ?? '',
      summary: json['summary'] ?? '',
      cuisines: List<String>.from(json['cuisines'] ?? []),
      dishTypes: List<String>.from(json['dishTypes'] ?? []),
      diets: List<String>.from(json['diets'] ?? []),
      extendedIngredients: (json['extendedIngredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e))
              .toList() ??
          [],
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
      image: json['image'] ?? '',
      readyInMinutes: json['readyInMinutes'] ?? 0,
      servings: json['servings'] ?? 1,
      sourceUrl: json['sourceUrl'] ?? '',
      summary: json['summary'] ?? '',
      cuisines: List<String>.from(json['cuisines'] ?? []),
      dishTypes: List<String>.from(json['dishTypes'] ?? []),
      diets: List<String>.from(json['diets'] ?? []),
      extendedIngredients: (json['extendedIngredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e))
              .toList() ??
          [],
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

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'] ?? 0,
      aisle: json['aisle'] ?? '',
      image: json['image'] ?? '',
      consistency: json['consistency'] ?? '',
      name: json['name'] ?? '',
      nameClean: json['nameClean'] ?? '',
      original: json['original'] ?? '',
      originalName: json['originalName'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      meta: List<String>.from(json['meta'] ?? []),
      measures: Measures.fromJson(json['measures'] ?? {}),
      isAvailableInPantry: json['isAvailableInPantry'] ?? false,
      isExpiring: json['isExpiring'] ?? false,
    );
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

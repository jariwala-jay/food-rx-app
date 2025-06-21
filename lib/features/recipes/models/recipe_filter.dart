enum CuisineType {
  american,
  asian,
  british,
  caribbean,
  centralEurope,
  chinese,
  easternEurope,
  european,
  french,
  german,
  greek,
  indian,
  irish,
  italian,
  japanese,
  jewish,
  korean,
  latinAmerican,
  mediterranean,
  mexican,
  middleEastern,
  nordic,
  southern,
  spanish,
  thai,
  vietnamese,
}

enum MealType {
  mainCourse,
  sideDish,
  dessert,
  appetizer,
  salad,
  bread,
  breakfast,
  soup,
  beverage,
  sauce,
  marinade,
  fingerfood,
  snack,
  drink,
}

enum DietType {
  glutenFree,
  ketogenic,
  vegetarian,
  lactoVegetarian,
  ovoVegetarian,
  vegan,
  pescetarian,
  paleo,
  primal,
  lowFodmap,
  whole30,
}

enum Intolerances {
  dairy,
  egg,
  gluten,
  grain,
  peanut,
  seafood,
  sesame,
  shellfish,
  soy,
  sulfite,
  treeNut,
  wheat,
}

enum MedicalCondition {
  hypertension,
  diabetes,
  prediabetes,
  obesity,
}

class RecipeFilter {
  final List<CuisineType> cuisines;
  final MealType? mealType;
  final List<DietType> diets;
  final List<Intolerances> intolerances;
  final List<MedicalCondition> medicalConditions;
  final int? maxReadyTime; // in minutes
  final int? servings;
  final bool includeIngredients; // Use pantry ingredients
  final bool excludeIngredients; // Exclude ingredients not in pantry
  final bool prioritizeExpiring; // Prioritize recipes using expiring items
  final bool dashCompliant; // DASH diet compliant
  final bool myPlateCompliant; // MyPlate guidelines compliant
  final int? maxCalories;
  final int? minProtein;
  final int? maxSodium;
  final int? maxSugar;
  final bool vegetarian;
  final bool vegan;
  final bool glutenFree;
  final bool dairyFree;
  final bool veryHealthy;
  final String? query; // Search query

  const RecipeFilter({
    this.cuisines = const [],
    this.mealType,
    this.diets = const [],
    this.intolerances = const [],
    this.medicalConditions = const [],
    this.maxReadyTime,
    this.servings,
    this.includeIngredients = true,
    this.excludeIngredients = false,
    this.prioritizeExpiring = true,
    this.dashCompliant = false,
    this.myPlateCompliant = false,
    this.maxCalories,
    this.minProtein,
    this.maxSodium,
    this.maxSugar,
    this.vegetarian = false,
    this.vegan = false,
    this.glutenFree = false,
    this.dairyFree = false,
    this.veryHealthy = false,
    this.query,
  });

  RecipeFilter copyWith({
    List<CuisineType>? cuisines,
    MealType? mealType,
    List<DietType>? diets,
    List<Intolerances>? intolerances,
    List<MedicalCondition>? medicalConditions,
    int? maxReadyTime,
    int? servings,
    bool? includeIngredients,
    bool? excludeIngredients,
    bool? prioritizeExpiring,
    bool? dashCompliant,
    bool? myPlateCompliant,
    int? maxCalories,
    int? minProtein,
    int? maxSodium,
    int? maxSugar,
    bool? vegetarian,
    bool? vegan,
    bool? glutenFree,
    bool? dairyFree,
    bool? veryHealthy,
    String? query,
  }) {
    return RecipeFilter(
      cuisines: cuisines ?? this.cuisines,
      mealType: mealType ?? this.mealType,
      diets: diets ?? this.diets,
      intolerances: intolerances ?? this.intolerances,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      maxReadyTime: maxReadyTime ?? this.maxReadyTime,
      servings: servings ?? this.servings,
      includeIngredients: includeIngredients ?? this.includeIngredients,
      excludeIngredients: excludeIngredients ?? this.excludeIngredients,
      prioritizeExpiring: prioritizeExpiring ?? this.prioritizeExpiring,
      dashCompliant: dashCompliant ?? this.dashCompliant,
      myPlateCompliant: myPlateCompliant ?? this.myPlateCompliant,
      maxCalories: maxCalories ?? this.maxCalories,
      minProtein: minProtein ?? this.minProtein,
      maxSodium: maxSodium ?? this.maxSodium,
      maxSugar: maxSugar ?? this.maxSugar,
      vegetarian: vegetarian ?? this.vegetarian,
      vegan: vegan ?? this.vegan,
      glutenFree: glutenFree ?? this.glutenFree,
      dairyFree: dairyFree ?? this.dairyFree,
      veryHealthy: veryHealthy ?? this.veryHealthy,
      query: query ?? this.query,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cuisines': cuisines.map((e) => e.name).toList(),
      'mealType': mealType?.name,
      'diets': diets.map((e) => e.name).toList(),
      'intolerances': intolerances.map((e) => e.name).toList(),
      'medicalConditions': medicalConditions.map((e) => e.name).toList(),
      'maxReadyTime': maxReadyTime,
      'servings': servings,
      'includeIngredients': includeIngredients,
      'excludeIngredients': excludeIngredients,
      'prioritizeExpiring': prioritizeExpiring,
      'dashCompliant': dashCompliant,
      'myPlateCompliant': myPlateCompliant,
      'maxCalories': maxCalories,
      'minProtein': minProtein,
      'maxSodium': maxSodium,
      'maxSugar': maxSugar,
      'vegetarian': vegetarian,
      'vegan': vegan,
      'glutenFree': glutenFree,
      'dairyFree': dairyFree,
      'veryHealthy': veryHealthy,
      'query': query,
    };
  }

  factory RecipeFilter.fromJson(Map<String, dynamic> json) {
    return RecipeFilter(
      cuisines: (json['cuisines'] as List<dynamic>?)
              ?.map((e) => CuisineType.values.firstWhere(
                    (cuisine) => cuisine.name == e,
                    orElse: () => CuisineType.american,
                  ))
              .toList() ??
          [],
      mealType: json['mealType'] != null
          ? MealType.values.firstWhere(
              (meal) => meal.name == json['mealType'],
              orElse: () => MealType.mainCourse,
            )
          : null,
      diets: (json['diets'] as List<dynamic>?)
              ?.map((e) => DietType.values.firstWhere(
                    (diet) => diet.name == e,
                    orElse: () => DietType.vegetarian,
                  ))
              .toList() ??
          [],
      intolerances: (json['intolerances'] as List<dynamic>?)
              ?.map((e) => Intolerances.values.firstWhere(
                    (intolerance) => intolerance.name == e,
                    orElse: () => Intolerances.dairy,
                  ))
              .toList() ??
          [],
      medicalConditions: (json['medicalConditions'] as List<dynamic>?)
              ?.map((e) => MedicalCondition.values.firstWhere(
                    (condition) => condition.name == e,
                    orElse: () => MedicalCondition.hypertension,
                  ))
              .toList() ??
          [],
      maxReadyTime: json['maxReadyTime'],
      servings: json['servings'],
      includeIngredients: json['includeIngredients'] ?? true,
      excludeIngredients: json['excludeIngredients'] ?? false,
      prioritizeExpiring: json['prioritizeExpiring'] ?? true,
      dashCompliant: json['dashCompliant'] ?? false,
      myPlateCompliant: json['myPlateCompliant'] ?? false,
      maxCalories: json['maxCalories'],
      minProtein: json['minProtein'],
      maxSodium: json['maxSodium'],
      maxSugar: json['maxSugar'],
      vegetarian: json['vegetarian'] ?? false,
      vegan: json['vegan'] ?? false,
      glutenFree: json['glutenFree'] ?? false,
      dairyFree: json['dairyFree'] ?? false,
      veryHealthy: json['veryHealthy'] ?? false,
      query: json['query'],
    );
  }

  // Helper methods for medical condition dietary constraints
  Map<String, dynamic> getMedicalConditionConstraints() {
    Map<String, dynamic> constraints = {};

    for (var condition in medicalConditions) {
      switch (condition) {
        case MedicalCondition.hypertension:
          constraints['maxSodium'] = 1500; // mg per day
          constraints['dashCompliant'] = true;
          break;
        case MedicalCondition.diabetes:
          constraints['maxSugar'] = 25; // g per serving
          constraints['lowGlycemic'] = true;
          break;
        case MedicalCondition.prediabetes:
          constraints['maxSugar'] = 25; // g per serving
          constraints['lowGlycemic'] = true;
          break;
        case MedicalCondition.obesity:
          constraints['maxCalories'] = 400; // per serving
          constraints['veryHealthy'] = true;
          break;
      }
    }

    return constraints;
  }

  // Convert to Spoonacular API query parameters
  Map<String, String> toSpoonacularParams() {
    Map<String, String> params = {};

    if (cuisines.isNotEmpty) {
      params['cuisine'] = cuisines.map((e) => e.name).join(',');
    }

    if (mealType != null) {
      params['type'] = mealType!.name;
    }

    if (diets.isNotEmpty) {
      params['diet'] = diets.map((e) => e.name).join(',');
    }

    if (intolerances.isNotEmpty) {
      params['intolerances'] = intolerances.map((e) => e.name).join(',');
    }

    if (maxReadyTime != null) {
      params['maxReadyTime'] = maxReadyTime.toString();
    }

    if (servings != null) {
      params['number'] = servings.toString();
    }

    if (query != null && query!.isNotEmpty) {
      params['query'] = query!;
    }

    // Add medical condition constraints
    final constraints = getMedicalConditionConstraints();
    constraints.forEach((key, value) {
      if (key == 'maxSodium' || key == 'maxSugar' || key == 'maxCalories') {
        params[key] = value.toString();
      } else if (key == 'veryHealthy' && value == true) {
        params['veryHealthy'] = 'true';
      }
    });

    // Add boolean filters
    if (vegetarian) params['vegetarian'] = 'true';
    if (vegan) params['vegan'] = 'true';
    if (glutenFree) params['glutenFree'] = 'true';
    if (dairyFree) params['dairyFree'] = 'true';
    if (veryHealthy) params['veryHealthy'] = 'true';

    return params;
  }
}

// Extension methods for enum display names
extension CuisineTypeExtension on CuisineType {
  String get displayName {
    switch (this) {
      case CuisineType.american:
        return 'American';
      case CuisineType.asian:
        return 'Asian';
      case CuisineType.british:
        return 'British';
      case CuisineType.caribbean:
        return 'Caribbean';
      case CuisineType.centralEurope:
        return 'Central European';
      case CuisineType.chinese:
        return 'Chinese';
      case CuisineType.easternEurope:
        return 'Eastern European';
      case CuisineType.european:
        return 'European';
      case CuisineType.french:
        return 'French';
      case CuisineType.german:
        return 'German';
      case CuisineType.greek:
        return 'Greek';
      case CuisineType.indian:
        return 'Indian';
      case CuisineType.irish:
        return 'Irish';
      case CuisineType.italian:
        return 'Italian';
      case CuisineType.japanese:
        return 'Japanese';
      case CuisineType.jewish:
        return 'Jewish';
      case CuisineType.korean:
        return 'Korean';
      case CuisineType.latinAmerican:
        return 'Latin American';
      case CuisineType.mediterranean:
        return 'Mediterranean';
      case CuisineType.mexican:
        return 'Mexican';
      case CuisineType.middleEastern:
        return 'Middle Eastern';
      case CuisineType.nordic:
        return 'Nordic';
      case CuisineType.southern:
        return 'Southern';
      case CuisineType.spanish:
        return 'Spanish';
      case CuisineType.thai:
        return 'Thai';
      case CuisineType.vietnamese:
        return 'Vietnamese';
    }
  }
}

extension MealTypeExtension on MealType {
  String get displayName {
    switch (this) {
      case MealType.mainCourse:
        return 'Main Course';
      case MealType.sideDish:
        return 'Side Dish';
      case MealType.dessert:
        return 'Dessert';
      case MealType.appetizer:
        return 'Appetizer';
      case MealType.salad:
        return 'Salad';
      case MealType.bread:
        return 'Bread';
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.soup:
        return 'Soup';
      case MealType.beverage:
        return 'Beverage';
      case MealType.sauce:
        return 'Sauce';
      case MealType.marinade:
        return 'Marinade';
      case MealType.fingerfood:
        return 'Finger Food';
      case MealType.snack:
        return 'Snack';
      case MealType.drink:
        return 'Drink';
    }
  }
}

extension MedicalConditionExtension on MedicalCondition {
  String get displayName {
    switch (this) {
      case MedicalCondition.hypertension:
        return 'Hypertension';
      case MedicalCondition.diabetes:
        return 'Diabetes';
      case MedicalCondition.prediabetes:
        return 'Pre-diabetes';
      case MedicalCondition.obesity:
        return 'Obesity';
    }
  }
}

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
  final String? spoonacularMealType; // Spoonacular API meal type string
  final List<String>?
      spoonacularMealTypes; // Multiple Spoonacular API meal types
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
    this.spoonacularMealType,
    this.spoonacularMealTypes,
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
    String? spoonacularMealType,
    List<String>? spoonacularMealTypes,
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
      spoonacularMealType: spoonacularMealType ?? this.spoonacularMealType,
      spoonacularMealTypes: spoonacularMealTypes ?? this.spoonacularMealTypes,
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
      'spoonacularMealType': spoonacularMealType,
      'spoonacularMealTypes': spoonacularMealTypes,
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
      spoonacularMealType: json['spoonacularMealType'],
      spoonacularMealTypes: json['spoonacularMealTypes'] != null
          ? List<String>.from(json['spoonacularMealTypes'])
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
          // DASH Diet Guidelines for Hypertension (practical approach)
          constraints['maxSodium'] =
              1500; // mg per day (more practical than 1500)
          constraints['dashCompliant'] = true;
          constraints['veryHealthy'] = true;
          constraints['maxSaturatedFat'] =
              8; // g per serving (slightly more lenient)
          constraints['minPotassium'] = 300; // mg per serving (more achievable)
          break;
        case MedicalCondition.diabetes:
          // ADA Guidelines for Diabetes (very practical approach)
          constraints['maxSugar'] = 45; // g per serving (increased from 35)
          constraints['maxCarbs'] = 75; // g per serving (increased from 60)
          // Remove minFiber constraint - let MyPlate handle it
          constraints['veryHealthy'] = true;
          constraints['maxSodium'] = 2300; // mg per day
          break;
        case MedicalCondition.prediabetes:
          // Pre-diabetes prevention guidelines (very practical)
          constraints['maxSugar'] = 45; // g per serving (increased from 35)
          constraints['maxCarbs'] = 75; // g per serving (increased from 60)
          // Remove minFiber constraint - let MyPlate handle it
          constraints['veryHealthy'] = true;
          constraints['maxSodium'] = 2300; // mg per day
          break;
        case MedicalCondition.obesity:
          // Weight management guidelines (very practical)
          constraints['maxCalories'] = 600; // per serving (increased from 500)
          constraints['minProtein'] = 10; // g per serving (reduced from 12)
          constraints['maxSaturatedFat'] =
              10; // g per serving (increased from 7)
          // Remove minFiber constraint - let MyPlate handle it
          constraints['veryHealthy'] = true;
          // Remove lowFat constraint - too restrictive
          break;
      }
    }

    return constraints;
  }

  // Get recommended diet type based on medical conditions and health goals
  static String getRecommendedDietType(
      List<String> medicalConditions, List<String> healthGoals) {
    // DASH diet for hypertension and blood pressure goals
    if (medicalConditions.contains('Hypertension') ||
        medicalConditions.contains('hypertension') ||
        healthGoals.contains('Lower blood pressure')) {
      return 'DASH';
    }

    // MyPlate for diabetes, obesity, and general health
    return 'MyPlate';
  }

  // Get DASH diet specific constraints
  Map<String, dynamic> getDashDietConstraints() {
    return {
      'maxSodium': 1500, // mg per day
      'minPotassium': 300, // mg per serving (more achievable)
      'maxSaturatedFat': 8, // g per serving (slightly more lenient)
      'minFiber': 2, // g per serving (more achievable)
      'veryHealthy': true,
      'lowFat': true,
      // Emphasize these food groups
      'emphasizeVegetables': true,
      'emphasizeFruits': true,
      'emphasizeLowFatDairy': true,
      'emphasizeLeanProtein': true,
      'emphasizeWoleGrains': true,
    };
  }

  // Get MyPlate diet specific constraints
  Map<String, dynamic> getMyPlateDietConstraints() {
    return {
      'maxSodium': 2300, // mg per day
      'maxSaturatedFat': 15, // g per day
      'maxSugar': 50, // g per day
      // Remove minFiber constraint - too restrictive when combined with medical conditions
      'veryHealthy': true,
      // Balanced nutrition approach
      'balancedNutrition': true,
      'emphasizeVariety': true,
      'portionControl': true,
    };
  }

  // Convert to Spoonacular API query parameters with enhanced diet-specific logic
  Map<String, String> toSpoonacularParams() {
    Map<String, String> params = {};

    if (cuisines.isNotEmpty) {
      params['cuisine'] = cuisines.map((e) => e.name).join(',');
    }

    if (spoonacularMealTypes != null && spoonacularMealTypes!.isNotEmpty) {
      // Use the first meal type as primary, others can be handled in separate calls
      params['type'] = spoonacularMealTypes!.first;
    } else if (spoonacularMealType != null) {
      params['type'] = spoonacularMealType!;
    } else if (mealType != null) {
      // Fallback to enum name if spoonacularMealType is not set
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
      if (key == 'maxSodium' ||
          key == 'maxSugar' ||
          key == 'maxCalories' ||
          key == 'minProtein' ||
          key == 'maxSaturatedFat' ||
          key == 'minFiber' ||
          key == 'minPotassium' ||
          key == 'maxCarbs') {
        params[key] = value.toString();
      } else if ((key == 'veryHealthy' ||
              key == 'lowFat' ||
              key == 'lowGlycemic') &&
          value == true) {
        params[key] = 'true';
      }
    });

    // Add diet-specific constraints
    if (dashCompliant) {
      final dashConstraints = getDashDietConstraints();
      dashConstraints.forEach((key, value) {
        if (key == 'maxSodium' ||
            key == 'minPotassium' ||
            key == 'maxSaturatedFat' ||
            key == 'minFiber') {
          params[key] = value.toString();
        } else if (key == 'veryHealthy' || key == 'lowFat') {
          params[key] = 'true';
        }
      });
    }

    if (myPlateCompliant) {
      final myPlateConstraints = getMyPlateDietConstraints();
      myPlateConstraints.forEach((key, value) {
        if (key == 'maxSodium' ||
            key == 'maxSaturatedFat' ||
            key == 'maxSugar' ||
            key == 'minFiber') {
          params[key] = value.toString();
        } else if (key == 'veryHealthy') {
          params[key] = 'true';
        }
      });
    }

    // Add boolean filters
    if (vegetarian) params['vegetarian'] = 'true';
    if (vegan) params['vegan'] = 'true';
    if (glutenFree) params['glutenFree'] = 'true';
    if (dairyFree) params['dairyFree'] = 'true';
    if (veryHealthy) params['veryHealthy'] = 'true';

    // Add nutrient-specific filters
    if (maxCalories != null) params['maxCalories'] = maxCalories.toString();
    if (minProtein != null) params['minProtein'] = minProtein.toString();
    if (maxSodium != null) params['maxSodium'] = maxSodium.toString();
    if (maxSugar != null) params['maxSugar'] = maxSugar.toString();

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

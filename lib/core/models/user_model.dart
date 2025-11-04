class UserModel {
  final String? id;
  final String email;
  final String? password;
  final String? name;
  final String? profilePhotoId;

  // Basic Health Information
  final int? age;
  final DateTime? dateOfBirth;
  final String? sex;
  final double? height;
  final String? heightUnit; // cm or inches
  final double? heightFeet;
  final double? heightInches;
  final double? weight;
  final String? weightUnit; // kg or lbs
  final String? activityLevel; // not active, light, moderate, very active
  final List<String>? medicalConditions;
  final List<String>? allergies;

  // Diet Preferences
  final String? dietType; // DASH or MyPlate
  final String? myPlanType; // "DASH", "MyPlate", "DiabetesPlate"
  final bool? showGlycemicIndex; // true if diabetes detected
  final List<String>? excludedIngredients;
  final List<String>? foodRestrictions;
  final List<String>? favoriteCuisines;
  final String? dailyFruitIntake;
  final String? dailyVegetableIntake;
  final String? dailyWaterIntake;
  final String? preferredMealPrepTime;
  final String? cookingForPeople;
  final String? cookingSkill;

  // Diet Plan Details
  final Map<String, dynamic>? selectedDietPlan;
  final int? targetCalories;
  final Map<String, double>? macroNutrients; // proteins, carbs, fats
  final Map<String, String>? mealTimings;
  final bool? requiresGroceryList;
  final Map<String, dynamic>?
      diagnostics; // Personalization diagnostics including diet rule

  // System Fields
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final int? failedLoginAttempts;
  final bool? isLocked;
  final DateTime? lockUntil;

  // Health Goals
  final List<String> healthGoals;

  // Tour completion
  final bool hasCompletedTour;

  UserModel({
    this.id,
    required this.email,
    this.password,
    this.name,
    this.profilePhotoId,
    // Health Info
    this.age,
    this.dateOfBirth,
    this.sex,
    this.height,
    this.heightUnit,
    this.heightFeet,
    this.heightInches,
    this.weight,
    this.weightUnit,
    this.activityLevel,
    this.medicalConditions,
    this.allergies,
    // Diet Preferences
    this.dietType,
    this.myPlanType,
    this.showGlycemicIndex,
    this.excludedIngredients,
    this.foodRestrictions,
    this.favoriteCuisines,
    this.dailyFruitIntake,
    this.dailyVegetableIntake,
    this.dailyWaterIntake,
    this.preferredMealPrepTime,
    this.cookingForPeople,
    this.cookingSkill,
    // Diet Plan
    this.selectedDietPlan,
    this.targetCalories,
    this.macroNutrients,
    this.mealTimings,
    this.requiresGroceryList,
    this.diagnostics,
    // System Fields
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.failedLoginAttempts,
    this.isLocked,
    this.lockUntil,
    // Health Goals
    this.healthGoals = const [],
    // Tour completion
    this.hasCompletedTour = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id']?.toString(),
      email: json['email'] ?? '',
      password: json['password'],
      name: json['name'],
      profilePhotoId: json['profilePhotoId'],
      // Health Info
      age: json['age'],
      dateOfBirth: json['dateOfBirth'] is String
          ? DateTime.parse(json['dateOfBirth'])
          : json['dateOfBirth'],
      sex: json['sex'],
      height: json['height']?.toDouble(),
      heightUnit: json['heightUnit'],
      heightFeet: json['heightFeet']?.toDouble(),
      heightInches: json['heightInches']?.toDouble(),
      weight: json['weight']?.toDouble(),
      weightUnit: json['weightUnit'],
      activityLevel: json['activityLevel'],
      medicalConditions: List<String>.from(json['medicalConditions'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      // Diet Preferences
      dietType: json['dietType'],
      myPlanType: json['myPlanType'],
      showGlycemicIndex: json['showGlycemicIndex'] == null
          ? null
          : json['showGlycemicIndex'] is bool
              ? json['showGlycemicIndex'] as bool
              : json['showGlycemicIndex'] == true ||
                  json['showGlycemicIndex'] == 'true' ||
                  json['showGlycemicIndex'] == 1,
      excludedIngredients: List<String>.from(json['excludedIngredients'] ?? []),
      foodRestrictions: List<String>.from(json['foodRestrictions'] ?? []),
      favoriteCuisines: List<String>.from(json['favoriteCuisines'] ?? []),
      dailyFruitIntake: json['dailyFruitIntake'],
      dailyVegetableIntake: json['dailyVegetableIntake'],
      dailyWaterIntake: json['dailyWaterIntake'],
      preferredMealPrepTime: json['preferredMealPrepTime'],
      cookingForPeople: json['cookingForPeople'],
      cookingSkill: json['cookingSkill'],
      // Diet Plan
      selectedDietPlan: json['selectedDietPlan'],
      targetCalories: json['targetCalories'],
      macroNutrients: Map<String, double>.from(json['macroNutrients'] ?? {}),
      mealTimings: Map<String, String>.from(json['mealTimings'] ?? {}),
      requiresGroceryList: json['requiresGroceryList'],
      diagnostics: json['diagnostics'],
      // System Fields
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'])
          : json['createdAt'],
      updatedAt: json['updatedAt'] is String
          ? DateTime.parse(json['updatedAt'])
          : json['updatedAt'],
      lastLoginAt: json['lastLoginAt'] is String
          ? DateTime.parse(json['lastLoginAt'])
          : json['lastLoginAt'],
      failedLoginAttempts: json['failedLoginAttempts'],
      isLocked: json['isLocked'],
      lockUntil: json['lockUntil'] is String
          ? DateTime.parse(json['lockUntil'])
          : json['lockUntil'],
      // Health Goals
      healthGoals: List<String>.from(json['healthGoals'] ?? []),
      // Tour completion
      hasCompletedTour: json['hasCompletedTour'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'name': name,
      'profilePhotoId': profilePhotoId,
      // Health Info
      'age': age,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'sex': sex,
      'height': height,
      'heightUnit': heightUnit,
      'heightFeet': heightFeet,
      'heightInches': heightInches,
      'weight': weight,
      'weightUnit': weightUnit,
      'activityLevel': activityLevel,
      'medicalConditions': medicalConditions,
      'allergies': allergies,
      // Diet Preferences
      'dietType': dietType,
      'myPlanType': myPlanType,
      'showGlycemicIndex': showGlycemicIndex,
      'excludedIngredients': excludedIngredients,
      'foodRestrictions': foodRestrictions,
      // Diet Plan
      'selectedDietPlan': selectedDietPlan,
      'targetCalories': targetCalories,
      'macroNutrients': macroNutrients,
      'mealTimings': mealTimings,
      'requiresGroceryList': requiresGroceryList,
      'diagnostics': diagnostics,
      // System Fields
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'failedLoginAttempts': failedLoginAttempts,
      'isLocked': isLocked,
      'lockUntil': lockUntil?.toIso8601String(),
      // Health Goals
      'healthGoals': healthGoals,
      // Tour completion
      'hasCompletedTour': hasCompletedTour,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? password,
    String? name,
    String? profilePhotoId,
    // Health Info
    int? age,
    DateTime? dateOfBirth,
    String? sex,
    double? height,
    String? heightUnit,
    double? heightFeet,
    double? heightInches,
    double? weight,
    String? weightUnit,
    String? activityLevel,
    List<String>? medicalConditions,
    List<String>? allergies,
    // Diet Preferences
    String? dietType,
    String? myPlanType,
    bool? showGlycemicIndex,
    List<String>? excludedIngredients,
    List<String>? foodRestrictions,
    // Diet Plan
    Map<String, dynamic>? selectedDietPlan,
    int? targetCalories,
    Map<String, double>? macroNutrients,
    Map<String, String>? mealTimings,
    bool? requiresGroceryList,
    Map<String, dynamic>? diagnostics,
    // System Fields
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    int? failedLoginAttempts,
    bool? isLocked,
    DateTime? lockUntil,
    // Health Goals
    List<String>? healthGoals,
    // Tour completion
    bool? hasCompletedTour,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      name: name ?? this.name,
      profilePhotoId: profilePhotoId ?? this.profilePhotoId,
      // Health Info
      age: age ?? this.age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      sex: sex ?? this.sex,
      height: height ?? this.height,
      heightUnit: heightUnit ?? this.heightUnit,
      heightFeet: heightFeet ?? this.heightFeet,
      heightInches: heightInches ?? this.heightInches,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      activityLevel: activityLevel ?? this.activityLevel,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      allergies: allergies ?? this.allergies,
      // Diet Preferences
      dietType: dietType ?? this.dietType,
      myPlanType: myPlanType ?? this.myPlanType,
      showGlycemicIndex: showGlycemicIndex ?? this.showGlycemicIndex,
      excludedIngredients: excludedIngredients ?? this.excludedIngredients,
      foodRestrictions: foodRestrictions ?? this.foodRestrictions,
      // Diet Plan
      selectedDietPlan: selectedDietPlan ?? this.selectedDietPlan,
      targetCalories: targetCalories ?? this.targetCalories,
      macroNutrients: macroNutrients ?? this.macroNutrients,
      mealTimings: mealTimings ?? this.mealTimings,
      requiresGroceryList: requiresGroceryList ?? this.requiresGroceryList,
      diagnostics: diagnostics ?? this.diagnostics,
      // System Fields
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      isLocked: isLocked ?? this.isLocked,
      lockUntil: lockUntil ?? this.lockUntil,
      // Health Goals
      healthGoals: healthGoals ?? this.healthGoals,
      // Tour completion
      hasCompletedTour: hasCompletedTour ?? this.hasCompletedTour,
    );
  }
}

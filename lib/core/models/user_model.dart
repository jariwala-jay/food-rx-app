class UserModel {
  final String? id;
  final String email;
  final String? password;
  final String? name;
  final String? profilePhotoId;

  // Basic Health Information
  final int? age;
  final String? gender;
  final double? height;
  final String? heightUnit; // cm or inches
  final double? weight;
  final String? weightUnit; // kg or lbs
  final String? activityLevel; // sedentary, light, moderate, very active
  final List<String>? medicalConditions;
  final List<String>? allergies;

  // Diet Preferences
  final String? dietType; // DASH or MyPlate
  final List<String>? excludedIngredients;
  final List<String>? foodRestrictions;

  // Diet Plan Details
  final Map<String, dynamic>? selectedDietPlan;
  final int? targetCalories;
  final Map<String, double>? macroNutrients; // proteins, carbs, fats
  final Map<String, String>? mealTimings;
  final bool? requiresGroceryList;

  // System Fields
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final int? failedLoginAttempts;
  final bool? isLocked;
  final DateTime? lockUntil;

  // Health Goals
  final List<String> healthGoals;

  UserModel({
    this.id,
    required this.email,
    this.password,
    this.name,
    this.profilePhotoId,
    // Health Info
    this.age,
    this.gender,
    this.height,
    this.heightUnit,
    this.weight,
    this.weightUnit,
    this.activityLevel,
    this.medicalConditions,
    this.allergies,
    // Diet Preferences
    this.dietType,
    this.excludedIngredients,
    this.foodRestrictions,
    // Diet Plan
    this.selectedDietPlan,
    this.targetCalories,
    this.macroNutrients,
    this.mealTimings,
    this.requiresGroceryList,
    // System Fields
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.failedLoginAttempts,
    this.isLocked,
    this.lockUntil,
    // Health Goals
    this.healthGoals = const [],
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
      gender: json['gender'],
      height: json['height']?.toDouble(),
      heightUnit: json['heightUnit'],
      weight: json['weight']?.toDouble(),
      weightUnit: json['weightUnit'],
      activityLevel: json['activityLevel'],
      medicalConditions: List<String>.from(json['medicalConditions'] ?? []),
      allergies: List<String>.from(json['allergies'] ?? []),
      // Diet Preferences
      dietType: json['dietType'],
      excludedIngredients: List<String>.from(json['excludedIngredients'] ?? []),
      foodRestrictions: List<String>.from(json['foodRestrictions'] ?? []),
      // Diet Plan
      selectedDietPlan: json['selectedDietPlan'],
      targetCalories: json['targetCalories'],
      macroNutrients: Map<String, double>.from(json['macroNutrients'] ?? {}),
      mealTimings: Map<String, String>.from(json['mealTimings'] ?? {}),
      requiresGroceryList: json['requiresGroceryList'],
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
      'gender': gender,
      'height': height,
      'heightUnit': heightUnit,
      'weight': weight,
      'weightUnit': weightUnit,
      'activityLevel': activityLevel,
      'medicalConditions': medicalConditions,
      'allergies': allergies,
      // Diet Preferences
      'dietType': dietType,
      'excludedIngredients': excludedIngredients,
      'foodRestrictions': foodRestrictions,
      // Diet Plan
      'selectedDietPlan': selectedDietPlan,
      'targetCalories': targetCalories,
      'macroNutrients': macroNutrients,
      'mealTimings': mealTimings,
      'requiresGroceryList': requiresGroceryList,
      // System Fields
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'failedLoginAttempts': failedLoginAttempts,
      'isLocked': isLocked,
      'lockUntil': lockUntil?.toIso8601String(),
      // Health Goals
      'healthGoals': healthGoals,
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
    String? gender,
    double? height,
    String? heightUnit,
    double? weight,
    String? weightUnit,
    String? activityLevel,
    List<String>? medicalConditions,
    List<String>? allergies,
    // Diet Preferences
    String? dietType,
    List<String>? excludedIngredients,
    List<String>? foodRestrictions,
    // Diet Plan
    Map<String, dynamic>? selectedDietPlan,
    int? targetCalories,
    Map<String, double>? macroNutrients,
    Map<String, String>? mealTimings,
    bool? requiresGroceryList,
    // System Fields
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    int? failedLoginAttempts,
    bool? isLocked,
    DateTime? lockUntil,
    // Health Goals
    List<String>? healthGoals,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      name: name ?? this.name,
      profilePhotoId: profilePhotoId ?? this.profilePhotoId,
      // Health Info
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      heightUnit: heightUnit ?? this.heightUnit,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      activityLevel: activityLevel ?? this.activityLevel,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      allergies: allergies ?? this.allergies,
      // Diet Preferences
      dietType: dietType ?? this.dietType,
      excludedIngredients: excludedIngredients ?? this.excludedIngredients,
      foodRestrictions: foodRestrictions ?? this.foodRestrictions,
      // Diet Plan
      selectedDietPlan: selectedDietPlan ?? this.selectedDietPlan,
      targetCalories: targetCalories ?? this.targetCalories,
      macroNutrients: macroNutrients ?? this.macroNutrients,
      mealTimings: mealTimings ?? this.mealTimings,
      requiresGroceryList: requiresGroceryList ?? this.requiresGroceryList,
      // System Fields
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      isLocked: isLocked ?? this.isLocked,
      lockUntil: lockUntil ?? this.lockUntil,
      // Health Goals
      healthGoals: healthGoals ?? this.healthGoals,
    );
  }
}

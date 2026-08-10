import 'package:flutter_app/core/models/excluded_ingredient.dart';

class SignupData {
  String? name;
  String? email;
  String? password;
  String? profilePhotoUrl;
  /// Google Sign-In ID token (JWT), held only for a brand-new Google account
  /// that hasn't finished onboarding yet — sent to /auth/google/complete at
  /// the final step to atomically create the account. Never serialized via
  /// toJson(); passed separately, like [password].
  ///
  /// This must be the ID token (`GoogleSignInAuthentication.idToken`), not
  /// the OAuth access token: the backend verifies its signature and audience
  /// against MyFoodRx's own OAuth client IDs, which an access token cannot
  /// be checked against.
  String? googleIdToken;
  DateTime? dateOfBirth;
  String? sex;
  double? heightFeet;
  double? heightInches;
  double? weight;
  List<String> medicalConditions;
  List<String> foodAllergies;
  List<ExcludedIngredient> excludedIngredients;
  String? activityLevel;
  List<String> healthGoals;
  String? dietType;
  String? myPlanType;
  bool showGlycemicIndex = false;
  List<String> favoriteCuisines;
  String? dailyFruitIntake;
  String? dailyVegetableIntake;
  String? dailyWaterIntake;
  String? preferredMealPrepTime;
  String? cookingForPeople;
  String? cookingSkill;
  int? targetCalories;
  Map<String, dynamic>? selectedDietPlan;
  Map<String, dynamic>? diagnostics;

  SignupData({
    this.name,
    this.email,
    this.password,
    this.profilePhotoUrl,
    this.googleIdToken,
    this.dateOfBirth,
    this.sex,
    this.heightFeet,
    this.heightInches,
    this.weight,
    this.medicalConditions = const [],
    this.foodAllergies = const [],
    this.excludedIngredients = const [],
    this.activityLevel,
    this.healthGoals = const [],
    this.dietType,
    this.myPlanType,
    this.showGlycemicIndex = false,
    this.favoriteCuisines = const [],
    this.dailyFruitIntake,
    this.dailyVegetableIntake,
    this.dailyWaterIntake,
    this.preferredMealPrepTime,
    this.cookingForPeople,
    this.cookingSkill,
    this.targetCalories,
    this.selectedDietPlan,
    this.diagnostics,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'email': email,
      'sex': sex,
      'heightFeet': heightFeet,
      'heightInches': heightInches,
      'weight': weight,
      'medicalConditions': medicalConditions,
      'allergies': foodAllergies,
      'foodRestrictions': foodAllergies,
      'excludedIngredients':
          excludedIngredients.map((ingredient) => ingredient.toJson()).toList(),
      'activityLevel': activityLevel,
      'healthGoals': healthGoals,
      'dietType': dietType,
      'myPlanType': myPlanType,
      'showGlycemicIndex': showGlycemicIndex,
      'favoriteCuisines': favoriteCuisines,
      'dailyFruitIntake': dailyFruitIntake,
      'dailyVegetableIntake': dailyVegetableIntake,
      'dailyWaterIntake': dailyWaterIntake,
      'preferredMealPrepTime': preferredMealPrepTime,
      'cookingForPeople': cookingForPeople,
      'cookingSkill': cookingSkill,
      'targetCalories': targetCalories,
      'selectedDietPlan': selectedDietPlan,
      'diagnostics': diagnostics,
    };

    if (dateOfBirth != null) {
      data['dateOfBirth'] = dateOfBirth!.toIso8601String();
    }
    if (profilePhotoUrl != null) {
      data['profilePhotoUrl'] = profilePhotoUrl;
    }

    data.removeWhere((key, value) => value == null);

    return data;
  }
}

class SignupData {
  String? name;
  String? email;
  String? password;
  DateTime? dateOfBirth;
  String? sex;
  double? heightFeet;
  double? heightInches;
  double? weight;
  List<String> medicalConditions;
  List<String> foodAllergies;
  String? activityLevel;
  List<String> healthGoals;
  String? dietType;
  // New fields for preferences step
  List<String> favoriteCuisines;
  String? dailyFruitIntake;
  String? dailyVegetableIntake;
  String? dailyWaterIntake;
  // New fields for other details step
  String? preferredMealPrepTime;
  String? cookingForPeople;
  String? cookingSkill;

  SignupData({
    this.name,
    this.email,
    this.password,
    this.dateOfBirth,
    this.sex,
    this.heightFeet,
    this.heightInches,
    this.weight,
    this.medicalConditions = const [],
    this.foodAllergies = const [],
    this.activityLevel,
    this.healthGoals = const [],
    this.dietType,
    this.favoriteCuisines = const [],
    this.dailyFruitIntake,
    this.dailyVegetableIntake,
    this.dailyWaterIntake,
    this.preferredMealPrepTime,
    this.cookingForPeople,
    this.cookingSkill,
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
      'foodAllergies': foodAllergies,
      'activityLevel': activityLevel,
      'healthGoals': healthGoals,
      'dietType': dietType,
      'favoriteCuisines': favoriteCuisines,
      'dailyFruitIntake': dailyFruitIntake,
      'dailyVegetableIntake': dailyVegetableIntake,
      'dailyWaterIntake': dailyWaterIntake,
      'preferredMealPrepTime': preferredMealPrepTime,
      'cookingForPeople': cookingForPeople,
      'cookingSkill': cookingSkill,
    };

    // Only add dateOfBirth if it's not null and convert it to ISO string
    if (dateOfBirth != null) {
      data['dateOfBirth'] = dateOfBirth!.toIso8601String();
    }

    // Remove null values
    data.removeWhere((key, value) => value == null);

    return data;
  }
}

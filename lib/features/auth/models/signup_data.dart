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
  int? targetCalories;
  Map<String, dynamic>? selectedDietPlan;
  Map<String, dynamic>? diagnostics;

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
      'foodAllergies': foodAllergies,
      'activityLevel': activityLevel,
      'healthGoals': healthGoals,
      'dietType': dietType,
      'targetCalories': targetCalories,
      'selectedDietPlan': selectedDietPlan,
      'diagnostics': diagnostics,
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

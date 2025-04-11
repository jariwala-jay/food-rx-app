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
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'sex': sex,
      'heightFeet': heightFeet,
      'heightInches': heightInches,
      'weight': weight,
      'medicalConditions': medicalConditions,
      'foodAllergies': foodAllergies,
      'activityLevel': activityLevel,
      'healthGoals': healthGoals,
    };
  }
}

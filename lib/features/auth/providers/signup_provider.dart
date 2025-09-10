import 'package:flutter/material.dart';
import 'package:flutter_app/features/auth/models/signup_data.dart';
import 'dart:io';

class SignupProvider extends ChangeNotifier {
  final SignupData _data = SignupData();
  int _currentStep = 0;
  File? _profilePhoto;

  SignupData get data => _data;
  int get currentStep => _currentStep;
  File? get profilePhoto => _profilePhoto;

  void updateBasicInfo({
    String? name,
    String? email,
    String? password,
    File? profilePhoto,
  }) {
    _data.name = name ?? _data.name;
    _data.email = email ?? _data.email;
    _data.password = password ?? _data.password;
    _profilePhoto = profilePhoto;
    notifyListeners();
  }

  void updateHealthInfo({
    DateTime? dateOfBirth,
    String? sex,
    double? heightFeet,
    double? heightInches,
    double? weight,
    List<String>? medicalConditions,
  }) {
    _data.dateOfBirth = dateOfBirth ?? _data.dateOfBirth;
    _data.sex = sex ?? _data.sex;
    _data.heightFeet = heightFeet ?? _data.heightFeet;
    _data.heightInches = heightInches ?? _data.heightInches;
    _data.weight = weight ?? _data.weight;
    _data.medicalConditions = medicalConditions ?? _data.medicalConditions;
    notifyListeners();
  }

  void updatePreferences({
    List<String>? foodAllergies,
    String? activityLevel,
    List<String>? favoriteCuisines,
    String? dailyFruitIntake,
    String? dailyVegetableIntake,
    String? dailyWaterIntake,
  }) {
    _data.foodAllergies = foodAllergies ?? _data.foodAllergies;
    _data.activityLevel = activityLevel ?? _data.activityLevel;
    _data.favoriteCuisines = favoriteCuisines ?? _data.favoriteCuisines;
    _data.dailyFruitIntake = dailyFruitIntake ?? _data.dailyFruitIntake;
    _data.dailyVegetableIntake =
        dailyVegetableIntake ?? _data.dailyVegetableIntake;
    _data.dailyWaterIntake = dailyWaterIntake ?? _data.dailyWaterIntake;
    notifyListeners();
  }

  void updateOtherDetails({
    List<String>? healthGoals,
    String? preferredMealPrepTime,
    String? cookingForPeople,
    String? cookingSkill,
  }) {
    _data.healthGoals = healthGoals ?? _data.healthGoals;
    _data.preferredMealPrepTime =
        preferredMealPrepTime ?? _data.preferredMealPrepTime;
    _data.cookingForPeople = cookingForPeople ?? _data.cookingForPeople;
    _data.cookingSkill = cookingSkill ?? _data.cookingSkill;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < 2) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  void setDietType(String? dietType) {
    _data.dietType = dietType;
    notifyListeners();
  }

  void reset() {
    _currentStep = 0;
    _data.name = null;
    _data.email = null;
    _data.password = null;
    _data.dateOfBirth = null;
    _data.sex = null;
    _data.heightFeet = null;
    _data.heightInches = null;
    _data.weight = null;
    _data.medicalConditions = [];
    _data.foodAllergies = [];
    _data.activityLevel = null;
    _data.healthGoals = [];
    _data.dietType = null;
    _data.favoriteCuisines = [];
    _data.dailyFruitIntake = null;
    _data.dailyVegetableIntake = null;
    _data.dailyWaterIntake = null;
    _data.preferredMealPrepTime = null;
    _data.cookingForPeople = null;
    _data.cookingSkill = null;
    _profilePhoto = null;
    notifyListeners();
  }
}

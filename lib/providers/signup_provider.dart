import 'package:flutter/material.dart';
import 'package:flutter_app/models/signup_data.dart';
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
    List<String>? healthGoals,
  }) {
    _data.foodAllergies = foodAllergies ?? _data.foodAllergies;
    _data.activityLevel = activityLevel ?? _data.activityLevel;
    _data.healthGoals = healthGoals ?? _data.healthGoals;
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
    _profilePhoto = null;
    notifyListeners();
  }
}

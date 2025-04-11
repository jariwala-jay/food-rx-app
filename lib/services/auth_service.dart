import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _email;

  bool get isAuthenticated => _isAuthenticated;
  String? get email => _email;

  Future<bool> login(String email, String password) async {
    // For demo purposes using static credentials
    if (email == 'admin' && password == '1234') {
      _isAuthenticated = true;
      _email = email;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _isAuthenticated = false;
    _email = null;
    notifyListeners();
  }
}

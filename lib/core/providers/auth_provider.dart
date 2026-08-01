import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  String? _userId;
  String? _userName;
  String? _userPhone;
  bool _isLoggedIn = false;
  bool _onboardingComplete = false;

  String? get userId => _userId;
  String? get userName => _userName;
  String? get userPhone => _userPhone;
  bool get isLoggedIn => _isLoggedIn;
  bool get onboardingComplete => _onboardingComplete;

  void login(String userId, String name, String phone) {
    _userId = userId;
    _userName = name;
    _userPhone = phone;
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _userId = null;
    _userName = null;
    _userPhone = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  void completeOnboarding() {
    _onboardingComplete = true;
    notifyListeners();
  }
}

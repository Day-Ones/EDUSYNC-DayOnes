import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService);

  final AuthService _authService;
  UserModel? _user;
  bool _loading = false;

  UserModel? get user => _user;
  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null;

  Future<void> bootstrap() async {
    _loading = true;
    notifyListeners();
    _user = await _authService.restoreSession();
    _loading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password, {required UserType role, bool remember = false}) async {
    _loading = true;
    notifyListeners();
    final result = await _authService.login(email, password, role: role, remember: remember);
    _user = result;
    _loading = false;
    notifyListeners();
    return result == null ? 'Invalid credentials or wrong role selected' : null;
  }

  Future<String?> signInWithGoogle({required UserType role}) async {
    _loading = true;
    notifyListeners();
    
    final result = await _authService.signInWithGoogle(role: role);
    
    if (result['success'] == true) {
      _user = result['user'] as UserModel;
      _loading = false;
      notifyListeners();
      return null;
    } else {
      _loading = false;
      notifyListeners();
      return result['message'] as String;
    }
  }

  Future<String?> signup({
    required String email,
    required String password,
    required String fullName,
    required UserType userType,
    String? studentId,
    String? facultyId,
    String? department,
  }) async {
    _loading = true;
    notifyListeners();
    final user = await _authService.signUp(
      email: email,
      password: password,
      fullName: fullName,
      userType: userType,
      studentId: studentId,
      facultyId: facultyId,
      department: department,
    );
    _user = user;
    _loading = false;
    notifyListeners();
    return user == null ? 'Failed to create account. Email may already be in use.' : null;
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }
}

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

  Future<String?> login(String email, String password,
      {required UserType role, bool remember = false}) async {
    _loading = true;
    notifyListeners();
    final result = await _authService.login(email, password,
        role: role, remember: remember);

    if (result.containsKey('user')) {
      _user = result['user'] as UserModel;
      _loading = false;
      notifyListeners();
      return null;
    } else {
      _loading = false;
      notifyListeners();
      return result['error'] as String? ?? 'Login failed';
    }
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
    String? gender,
    DateTime? dateOfBirth,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final user = await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        userType: userType,
        gender: gender,
        dateOfBirth: dateOfBirth,
      );
      _user = user;
      _loading = false;
      notifyListeners();
      return user == null ? 'Failed to create account' : null;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<bool> isEmailInUse(String email) async {
    try {
      return await _authService.isEmailInUse(email);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkEmailStatus(String email) async {
    try {
      return await _authService.checkEmailStatus(email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> updateUser(UserModel updatedUser) async {
    _user = updatedUser;
    // Persist the updated user to storage
    await _authService.updateUser(updatedUser);
    notifyListeners();
  }

  Future<String?> updateEmail(String newEmail) async {
    _loading = true;
    notifyListeners();
    try {
      await _authService.updateEmail(newEmail);
      _loading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> changePassword(
      String currentPassword, String newPassword) async {
    _loading = true;
    notifyListeners();
    try {
      await _authService.changePassword(currentPassword, newPassword);
      _loading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}

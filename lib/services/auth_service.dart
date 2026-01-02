import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../models/user.dart';

class AuthService {
  AuthService(this._storage);
  final FlutterSecureStorage _storage;

  static const _keyUsers = 'auth_users';
  static const _keySession = 'auth_session';

  Future<UserModel?> login(String email, String password, {required UserType role, bool remember = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await _loadUsers();
    UserModel? user;
    for (final u in users) {
      final storedHash = await _getStoredHash(u.id);
      if (u.userType == role && u.email.toLowerCase() == email.toLowerCase() && _hash(password) == storedHash) {
        user = u;
        break;
      }
    }
    if (user != null) {
      await _storage.write(key: _keySession, value: user.id);
      if (remember) {
        await prefs.setString('remember_email', email);
      }
    }
    return user;
  }

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserType userType,
    String? studentId,
    String? facultyId,
    String? department,
  }) async {
    final users = await _loadUsers();
    final newUser = UserModel(
      id: UniqueKey().toString(),
      email: email,
      fullName: fullName,
      userType: userType,
      studentId: studentId,
      facultyId: facultyId,
      department: department,
      isGoogleCalendarConnected: false,
    );
    users.add(newUser);
    await _saveUsers(users);
    await _storeHash(newUser.id, _hash(password));
    await _storage.write(key: _keySession, value: newUser.id);
    return newUser;
  }

  Future<UserModel?> restoreSession() async {
    final sessionId = await _storage.read(key: _keySession);
    if (sessionId == null) return null;
    final users = await _loadUsers();
    return users.firstWhereOrNull((u) => u.id == sessionId);
  }

  Future<void> logout() async {
    await _storage.delete(key: _keySession);
  }

  Future<List<UserModel>> _loadUsers() async {
    final raw = await _storage.read(key: _keyUsers);
    if (raw == null) {
      final seed = await _seedUsers();
      await _saveUsers(seed);
      return seed;
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => _fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveUsers(List<UserModel> users) async {
    final encoded = jsonEncode(users.map(_toMap).toList());
    await _storage.write(key: _keyUsers, value: encoded);
  }

  String _hash(String input) => base64Encode(utf8.encode(input));

  Future<void> _storeHash(String userId, String hash) async {
    await _storage.write(key: 'hash_$userId', value: hash);
  }

  Future<String?> _getStoredHash(String userId) => _storage.read(key: 'hash_$userId');

  Future<List<UserModel>> _seedUsers() async {
    final student = UserModel(
      id: 'seed-student',
      email: 'student@test.com',
      fullName: 'Test Student',
      userType: UserType.student,
      studentId: 'S12345',
      department: 'Computer Science',
      isGoogleCalendarConnected: false,
    );
    final faculty = UserModel(
      id: 'seed-faculty',
      email: 'faculty@test.com',
      fullName: 'Prof. Ada Lovelace',
      userType: UserType.faculty,
      facultyId: 'F6789',
      department: 'Mathematics',
      isGoogleCalendarConnected: false,
    );
    await _storeHash(student.id, _hash('password123'));
    await _storeHash(faculty.id, _hash('password123'));
    return [student, faculty];
  }

  Map<String, dynamic> _toMap(UserModel u) => {
        'id': u.id,
        'email': u.email,
        'fullName': u.fullName,
        'userType': u.userType.name,
        'studentId': u.studentId,
        'facultyId': u.facultyId,
        'department': u.department,
        'googleAccountEmail': u.googleAccountEmail,
        'isGoogleCalendarConnected': u.isGoogleCalendarConnected,
        'createdAt': u.createdAt.toIso8601String(),
      };

  UserModel _fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String,
      fullName: map['fullName'] as String,
      userType: map['userType'] == 'faculty' ? UserType.faculty : UserType.student,
      studentId: map['studentId'] as String?,
      facultyId: map['facultyId'] as String?,
      department: map['department'] as String?,
      googleAccountEmail: map['googleAccountEmail'] as String?,
      isGoogleCalendarConnected: (map['isGoogleCalendarConnected'] as bool?) ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

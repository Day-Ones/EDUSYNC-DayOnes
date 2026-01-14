import 'package:flutter/material.dart';
import 'package:smart_scheduler/models/class.dart';
import 'package:smart_scheduler/services/local_db_service.dart';

class ClassProvider extends ChangeNotifier {
  ClassProvider(this._dbService);

  final LocalDbService _dbService;
  List<ClassModel> _classes = [];
  List<ClassModel> _enrolledClasses = [];
  bool _loading = false;
  String? _currentUserId;

  List<ClassModel> get classes => _classes;
  List<ClassModel> get enrolledClasses => _enrolledClasses;
  List<ClassModel> get allClasses => [..._classes, ..._enrolledClasses];
  bool get isLoading => _loading;

  Future<void> loadForUser(String userId, {required bool isStudent}) async {
    _loading = true;
    _currentUserId = userId;
    notifyListeners();
    
    _classes = await _dbService.loadClasses(userId);
    
    // For students, also load enrolled classes
    if (isStudent) {
      _enrolledClasses = await _dbService.loadEnrolledClasses(userId);
    } else {
      _enrolledClasses = [];
    }
    
    // No sample classes - users create their own
    _loading = false;
    notifyListeners();
  }

  Future<void> addOrUpdate(ClassModel model) async {
    final exists = _classes.indexWhere((c) => c.id == model.id);
    if (exists >= 0) {
      _classes[exists] = model;
      await _dbService.updateClass(model);
    } else {
      _classes.add(model);
      await _dbService.insertClass(model);
    }
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _classes.removeWhere((c) => c.id == id);
    await _dbService.deleteClass(id);
    notifyListeners();
  }

  // Join class with invite code
  Future<String?> joinClassWithCode(String inviteCode, String studentId) async {
    final classModel = await _dbService.findClassByInviteCode(inviteCode);
    if (classModel == null) {
      return 'Invalid invite code. Please check and try again.';
    }
    
    if (classModel.enrolledStudentIds.contains(studentId)) {
      return 'You are already enrolled in this class.';
    }
    
    final success = await _dbService.enrollStudentInClass(classModel.id, studentId);
    if (success) {
      // Reload enrolled classes
      _enrolledClasses = await _dbService.loadEnrolledClasses(studentId);
      notifyListeners();
      return null; // Success
    }
    return 'Failed to join class. Please try again.';
  }

  // Leave enrolled class
  Future<void> leaveClass(String classId) async {
    if (_currentUserId == null) return;
    await _dbService.unenrollStudentFromClass(classId, _currentUserId!);
    _enrolledClasses.removeWhere((c) => c.id == classId);
    notifyListeners();
  }

  // Get class by ID
  ClassModel? getClassById(String id) {
    try {
      return allClasses.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Regenerate invite code for a class
  Future<void> regenerateInviteCode(String classId) async {
    final idx = _classes.indexWhere((c) => c.id == classId);
    if (idx >= 0) {
      final newCode = ClassModel.generateInviteCode();
      final updated = _classes[idx].copyWith(inviteCode: newCode);
      _classes[idx] = updated;
      await _dbService.updateClass(updated);
      notifyListeners();
    }
  }
}

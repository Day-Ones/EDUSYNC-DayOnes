import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/class.dart';
import '../models/schedule.dart';

class LocalDbService {
  static const _keyClasses = 'classes_storage_v1';
  static const _keySchedules = 'schedules_storage_v1';

  Future<List<ClassModel>> loadClasses(String userId) async {
    final all = await _loadAll();
    return all.where((c) => c.userId == userId).toList();
  }

  // Load classes where student is enrolled
  Future<List<ClassModel>> loadEnrolledClasses(String studentId) async {
    final all = await _loadAll();
    return all.where((c) => c.enrolledStudentIds.contains(studentId)).toList();
  }

  // Find class by invite code
  Future<ClassModel?> findClassByInviteCode(String inviteCode) async {
    final all = await _loadAll();
    try {
      return all.firstWhere((c) => c.inviteCode == inviteCode.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  // Enroll student in class
  Future<bool> enrollStudentInClass(String classId, String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final classes = await _loadAll();
    final idx = classes.indexWhere((c) => c.id == classId);
    if (idx >= 0) {
      final classModel = classes[idx];
      if (!classModel.enrolledStudentIds.contains(studentId)) {
        final updatedStudents = [...classModel.enrolledStudentIds, studentId];
        classes[idx] = classModel.copyWith(enrolledStudentIds: updatedStudents);
        await _save(prefs, classes);
        return true;
      }
    }
    return false;
  }

  // Remove student from class
  Future<void> unenrollStudentFromClass(
      String classId, String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final classes = await _loadAll();
    final idx = classes.indexWhere((c) => c.id == classId);
    if (idx >= 0) {
      final classModel = classes[idx];
      final updatedStudents =
          classModel.enrolledStudentIds.where((id) => id != studentId).toList();
      classes[idx] = classModel.copyWith(enrolledStudentIds: updatedStudents);
      await _save(prefs, classes);
    }
  }

  Future<void> insertClass(ClassModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll();

    // Check if class already exists
    final existingIdx = all.indexWhere((c) => c.id == model.id);
    if (existingIdx >= 0) {
      // Update existing class instead of adding duplicate
      all[existingIdx] = model;
    } else {
      // Add new class
      all.add(model);
    }

    await _save(prefs, all);
  }

  Future<void> updateClass(ClassModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final classes = await _loadAll();
    final idx = classes.indexWhere((c) => c.id == model.id);
    if (idx >= 0) {
      classes[idx] = model;
    } else {
      // If class doesn't exist, add it
      classes.add(model);
    }
    await _save(prefs, classes);
  }

  Future<void> deleteClass(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll();
    all.removeWhere((c) => c.id == id);
    await _save(prefs, all);
  }

  Future<void> _save(SharedPreferences prefs, List<ClassModel> classes) async {
    await prefs.setString(
        _keyClasses, jsonEncode(classes.map((c) => c.toMap()).toList()));
  }

  Future<List<ClassModel>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyClasses);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ClassModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // No sample classes - users create their own or join via invite code
  List<ClassModel> sampleClasses(String userId, bool isStudent) {
    return []; // Return empty list - no hardcoded data
  }

  // Schedule methods
  Future<List<ScheduleModel>> loadSchedules(String userId) async {
    final all = await _loadAllSchedules();
    return all.where((s) => s.userId == userId).toList();
  }

  Future<void> insertSchedule(ScheduleModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAllSchedules();
    all.add(model);
    await _saveSchedules(prefs, all);
  }

  Future<void> updateSchedule(ScheduleModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final schedules = await _loadAllSchedules();
    final idx = schedules.indexWhere((s) => s.id == model.id);
    if (idx >= 0) {
      schedules[idx] = model;
      await _saveSchedules(prefs, schedules);
    }
  }

  Future<void> deleteSchedule(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAllSchedules();
    all.removeWhere((s) => s.id == id);
    await _saveSchedules(prefs, all);
  }

  Future<void> _saveSchedules(
      SharedPreferences prefs, List<ScheduleModel> schedules) async {
    await prefs.setString(
        _keySchedules, jsonEncode(schedules.map((s) => s.toMap()).toList()));
  }

  Future<List<ScheduleModel>> _loadAllSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySchedules);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ScheduleModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

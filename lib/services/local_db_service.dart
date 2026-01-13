import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/class.dart';
import '../models/schedule.dart';
import '../theme/app_theme.dart';

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
  Future<void> unenrollStudentFromClass(String classId, String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final classes = await _loadAll();
    final idx = classes.indexWhere((c) => c.id == classId);
    if (idx >= 0) {
      final classModel = classes[idx];
      final updatedStudents = classModel.enrolledStudentIds.where((id) => id != studentId).toList();
      classes[idx] = classModel.copyWith(enrolledStudentIds: updatedStudents);
      await _save(prefs, classes);
    }
  }

  Future<void> insertClass(ClassModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll();
    all.add(model);
    await _save(prefs, all);
  }

  Future<void> updateClass(ClassModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final classes = await _loadAll();
    final idx = classes.indexWhere((c) => c.id == model.id);
    if (idx >= 0) {
      classes[idx] = model;
      await _save(prefs, classes);
    }
  }

  Future<void> deleteClass(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll();
    all.removeWhere((c) => c.id == id);
    await _save(prefs, all);
  }

  Future<void> _save(SharedPreferences prefs, List<ClassModel> classes) async {
    await prefs.setString(_keyClasses, jsonEncode(classes.map((c) => c.toMap()).toList()));
  }

  Future<List<ClassModel>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyClasses);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => ClassModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  List<ClassModel> sampleClasses(String userId, bool isStudent) {
    if (isStudent) return []; // Students don't get sample classes, they join via invite
    
    return [
      ClassModel(
        id: 'cls-1',
        userId: userId,
        name: 'CS 101 Lecture',
        daysOfWeek: const [1, 3, 5],
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 30),
        instructorOrRoom: 'Room B201',
        location: 'Main Building',
        notes: 'Intro to programming',
        color: AppColors.classPalette.first,
        alerts: [
          AlertModel(timeBefore: const Duration(hours: 24), isEnabled: true),
          AlertModel(timeBefore: const Duration(minutes: 15), isEnabled: true),
        ],
        syncWithGoogle: true,
        isModifiedLocally: false,
        lastSyncedAt: DateTime.now().subtract(const Duration(hours: 3)),
        inviteCode: ClassModel.generateInviteCode(),
        facultyId: userId,
        facultyName: 'Faculty',
        campusLocation: PredefinedCampuses.campuses.first,
        enrolledStudentIds: [],
      ),
    ];
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

  Future<void> _saveSchedules(SharedPreferences prefs, List<ScheduleModel> schedules) async {
    await prefs.setString(_keySchedules, jsonEncode(schedules.map((s) => s.toMap()).toList()));
  }

  Future<List<ScheduleModel>> _loadAllSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySchedules);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => ScheduleModel.fromMap(e as Map<String, dynamic>)).toList();
  }

}

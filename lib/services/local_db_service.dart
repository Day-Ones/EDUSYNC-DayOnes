import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

class LocalDbService {
  static const _keyClasses = 'classes_storage_v1';

  Future<List<ClassModel>> loadClasses(String userId) async {
    final all = await _loadAll();
    return all.where((c) => c.userId == userId).toList();
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
    await prefs.setString(_keyClasses, jsonEncode(classes.map(_toMap).toList()));
  }

  Future<List<ClassModel>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyClasses);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => _fromMap(e as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> _toMap(ClassModel c) => {
        'id': c.id,
        'userId': c.userId,
        'name': c.name,
        'daysOfWeek': c.daysOfWeek,
        'startHour': c.startTime.hour,
        'startMinute': c.startTime.minute,
        'endHour': c.endTime.hour,
        'endMinute': c.endTime.minute,
        'instructorOrRoom': c.instructorOrRoom,
        'location': c.location,
        'notes': c.notes,
        'color': c.color.value,
        'alerts': c.alerts
            .map((a) => {'timeBefore': a.timeBefore.inMinutes, 'isEnabled': a.isEnabled})
            .toList(),
        'googleEventId': c.googleEventId,
        'lastSyncedAt': c.lastSyncedAt?.toIso8601String(),
        'syncWithGoogle': c.syncWithGoogle,
        'isModifiedLocally': c.isModifiedLocally,
        'createdAt': c.createdAt.toIso8601String(),
        'updatedAt': c.updatedAt.toIso8601String(),
      };

  ClassModel _fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      name: map['name'] as String,
      daysOfWeek: List<int>.from(map['daysOfWeek'] as List<dynamic>),
      startTime: TimeOfDay(hour: map['startHour'] as int, minute: map['startMinute'] as int),
      endTime: TimeOfDay(hour: map['endHour'] as int, minute: map['endMinute'] as int),
      instructorOrRoom: map['instructorOrRoom'] as String,
      location: map['location'] as String,
      notes: map['notes'] as String,
      color: Color(map['color'] as int),
      alerts: (map['alerts'] as List<dynamic>)
          .map((a) => AlertModel(
                timeBefore: Duration(minutes: (a as Map<String, dynamic>)['timeBefore'] as int),
                isEnabled: (a)['isEnabled'] as bool,
              ))
          .toList(),
      googleEventId: map['googleEventId'] as String?,
      lastSyncedAt: map['lastSyncedAt'] != null
          ? DateTime.tryParse(map['lastSyncedAt'] as String)
          : null,
      syncWithGoogle: (map['syncWithGoogle'] as bool?) ?? false,
      isModifiedLocally: (map['isModifiedLocally'] as bool?) ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  List<ClassModel> sampleClasses(String userId, bool isStudent) {
    return [
      ClassModel(
        id: 'cls-1',
        userId: userId,
        name: isStudent ? 'CS 101' : 'CS 101 Lecture',
        daysOfWeek: const [1, 3, 5],
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 11, minute: 30),
        instructorOrRoom: isStudent ? 'Dr. Smith' : 'Room B201',
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
      ),
    ];
  }
}

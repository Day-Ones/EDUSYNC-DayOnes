import 'package:flutter/material.dart';

enum UserType { student, faculty }

class UserModel {
  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.userType,
    this.studentId,
    this.facultyId,
    this.department,
    this.googleAccountEmail,
    this.isGoogleCalendarConnected = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String email;
  final String fullName;
  final UserType userType;
  final String? studentId;
  final String? facultyId;
  final String? department;
  final String? googleAccountEmail;
  final bool isGoogleCalendarConnected;
  final DateTime createdAt;

  UserModel copyWith({
    String? email,
    String? fullName,
    UserType? userType,
    String? studentId,
    String? facultyId,
    String? department,
    String? googleAccountEmail,
    bool? isGoogleCalendarConnected,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      userType: userType ?? this.userType,
      studentId: studentId ?? this.studentId,
      facultyId: facultyId ?? this.facultyId,
      department: department ?? this.department,
      googleAccountEmail: googleAccountEmail ?? this.googleAccountEmail,
      isGoogleCalendarConnected:
          isGoogleCalendarConnected ?? this.isGoogleCalendarConnected,
      createdAt: createdAt,
    );
  }
}

class AlertModel {
  AlertModel({required this.timeBefore, required this.isEnabled});

  final Duration timeBefore;
  final bool isEnabled;
}

class ClassModel {
  ClassModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    required this.instructorOrRoom,
    required this.location,
    required this.notes,
    required this.color,
    required this.alerts,
    this.googleEventId,
    this.lastSyncedAt,
    this.syncWithGoogle = false,
    this.isModifiedLocally = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String userId;
  final String name;
  final List<int> daysOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String instructorOrRoom;
  final String location;
  final String notes;
  final Color color;
  final List<AlertModel> alerts;
  final String? googleEventId;
  final DateTime? lastSyncedAt;
  final bool syncWithGoogle;
  final bool isModifiedLocally;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClassModel copyWith({
    String? name,
    List<int>? daysOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? instructorOrRoom,
    String? location,
    String? notes,
    Color? color,
    List<AlertModel>? alerts,
    String? googleEventId,
    DateTime? lastSyncedAt,
    bool? syncWithGoogle,
    bool? isModifiedLocally,
    DateTime? updatedAt,
  }) {
    return ClassModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      instructorOrRoom: instructorOrRoom ?? this.instructorOrRoom,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      color: color ?? this.color,
      alerts: alerts ?? this.alerts,
      googleEventId: googleEventId ?? this.googleEventId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncWithGoogle: syncWithGoogle ?? this.syncWithGoogle,
      isModifiedLocally: isModifiedLocally ?? this.isModifiedLocally,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

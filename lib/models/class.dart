import 'dart:math';
import 'package:flutter/material.dart';

/// Represents an alert/reminder for a class
class AlertModel {
  AlertModel({
    required this.timeBefore,
    required this.isEnabled,
  });

  final Duration timeBefore;
  final bool isEnabled;

  AlertModel copyWith({
    Duration? timeBefore,
    bool? isEnabled,
  }) {
    return AlertModel(
      timeBefore: timeBefore ?? this.timeBefore,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() => {
        'timeBeforeMinutes': timeBefore.inMinutes,
        'isEnabled': isEnabled,
      };

  factory AlertModel.fromMap(Map<String, dynamic> map) {
    return AlertModel(
      timeBefore: Duration(minutes: map['timeBeforeMinutes'] as int),
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory AlertModel.fromJson(Map<String, dynamic> json) =>
      AlertModel.fromMap(json);
}

/// Represents a campus location with building and room information
class CampusLocationModel {
  CampusLocationModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.building,
    this.room,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? building;
  final String? room;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CampusLocationModel &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => name.hashCode ^ latitude.hashCode ^ longitude.hashCode;

  CampusLocationModel copyWith({
    String? name,
    double? latitude,
    double? longitude,
    String? building,
    String? room,
  }) {
    return CampusLocationModel(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      building: building ?? this.building,
      room: room ?? this.room,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'building': building,
        'room': room,
      };

  factory CampusLocationModel.fromMap(Map<String, dynamic> map) {
    return CampusLocationModel(
      name: map['name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      building: map['building'] as String?,
      room: map['room'] as String?,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory CampusLocationModel.fromJson(Map<String, dynamic> json) =>
      CampusLocationModel.fromMap(json);
}

/// Represents a class/course in the system
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
    required this.color,
    required this.alerts,
    required this.isModifiedLocally,
    this.lastSyncedAt,
    this.inviteCode,
    this.facultyId,
    this.facultyName,
    this.campusLocation,
    this.enrolledStudentIds = const [],
    this.lateGracePeriodMinutes = 10,
    this.absentGracePeriodMinutes = 30,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String userId;
  final String name;
  final List<int> daysOfWeek; // 1 = Monday, 7 = Sunday
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String instructorOrRoom;
  final String location;
  final Color color;
  final List<AlertModel> alerts;
  final bool isModifiedLocally;
  final DateTime? lastSyncedAt;
  final String? inviteCode;
  final String? facultyId;
  final String? facultyName;
  final CampusLocationModel? campusLocation;
  final List<String> enrolledStudentIds;
  final int lateGracePeriodMinutes;
  final int absentGracePeriodMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Generate a random 6-character invite code
  static String generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  ClassModel copyWith({
    String? name,
    List<int>? daysOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? instructorOrRoom,
    String? location,
    Color? color,
    List<AlertModel>? alerts,
    bool? isModifiedLocally,
    DateTime? lastSyncedAt,
    String? inviteCode,
    String? facultyId,
    String? facultyName,
    CampusLocationModel? campusLocation,
    List<String>? enrolledStudentIds,
    int? lateGracePeriodMinutes,
    int? absentGracePeriodMinutes,
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
      color: color ?? this.color,
      alerts: alerts ?? this.alerts,
      isModifiedLocally: isModifiedLocally ?? this.isModifiedLocally,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      inviteCode: inviteCode ?? this.inviteCode,
      facultyId: facultyId ?? this.facultyId,
      facultyName: facultyName ?? this.facultyName,
      campusLocation: campusLocation ?? this.campusLocation,
      enrolledStudentIds: enrolledStudentIds ?? this.enrolledStudentIds,
      lateGracePeriodMinutes:
          lateGracePeriodMinutes ?? this.lateGracePeriodMinutes,
      absentGracePeriodMinutes:
          absentGracePeriodMinutes ?? this.absentGracePeriodMinutes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'daysOfWeek': daysOfWeek,
        'startHour': startTime.hour,
        'startMinute': startTime.minute,
        'endHour': endTime.hour,
        'endMinute': endTime.minute,
        'instructorOrRoom': instructorOrRoom,
        'location': location,
        'color': color.value,
        'alerts': alerts.map((a) => a.toMap()).toList(),
        'isModifiedLocally': isModifiedLocally,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'inviteCode': inviteCode,
        'facultyId': facultyId,
        'facultyName': facultyName,
        'campusLocation': campusLocation?.toMap(),
        'enrolledStudentIds': enrolledStudentIds,
        'lateGracePeriodMinutes': lateGracePeriodMinutes,
        'absentGracePeriodMinutes': absentGracePeriodMinutes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      name: map['name'] as String,
      daysOfWeek: List<int>.from(map['daysOfWeek'] as List<dynamic>),
      startTime: TimeOfDay(
        hour: map['startHour'] as int,
        minute: map['startMinute'] as int,
      ),
      endTime: TimeOfDay(
        hour: map['endHour'] as int,
        minute: map['endMinute'] as int,
      ),
      instructorOrRoom: map['instructorOrRoom'] as String? ?? '',
      location: map['location'] as String? ?? '',
      color: Color(map['color'] as int),
      alerts: (map['alerts'] as List<dynamic>?)
              ?.map((e) => AlertModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      isModifiedLocally: map['isModifiedLocally'] as bool? ?? false,
      lastSyncedAt: map['lastSyncedAt'] != null
          ? DateTime.tryParse(map['lastSyncedAt'] as String)
          : null,
      inviteCode: map['inviteCode'] as String?,
      facultyId: map['facultyId'] as String?,
      facultyName: map['facultyName'] as String?,
      campusLocation: map['campusLocation'] != null
          ? CampusLocationModel.fromMap(
              map['campusLocation'] as Map<String, dynamic>)
          : null,
      enrolledStudentIds:
          List<String>.from(map['enrolledStudentIds'] as List<dynamic>? ?? []),
      lateGracePeriodMinutes: map['lateGracePeriodMinutes'] as int? ?? 10,
      absentGracePeriodMinutes: map['absentGracePeriodMinutes'] as int? ?? 30,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory ClassModel.fromJson(Map<String, dynamic> json) =>
      ClassModel.fromMap(json);

  /// Check if this class conflicts with another class
  bool conflictsWith(ClassModel other) {
    // Check if days overlap
    final daysOverlap = daysOfWeek.any((d) => other.daysOfWeek.contains(d));
    if (!daysOverlap) return false;

    // Check time overlap
    final thisStart = startTime.hour * 60 + startTime.minute;
    final thisEnd = endTime.hour * 60 + endTime.minute;
    final otherStart = other.startTime.hour * 60 + other.startTime.minute;
    final otherEnd = other.endTime.hour * 60 + other.endTime.minute;

    return thisStart < otherEnd && thisEnd > otherStart;
  }
}

/// Predefined campus locations for selection
class PredefinedCampuses {
  static final List<CampusLocationModel> campuses = [
    CampusLocationModel(
      name: 'PUP Taguig Campus',
      latitude: 14.5176,
      longitude: 121.0509,
      building: 'Main Building',
    ),
  ];
}

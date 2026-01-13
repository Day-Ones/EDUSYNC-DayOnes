import 'package:flutter/material.dart';

enum ScheduleType { personal, academic, office }

class ScheduleModel {
  ScheduleModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.scheduleType,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.color,
    this.location,
    this.isRecurring = false,
    this.recurringDays = const [],
    this.reminderMinutes = 15,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String userId;
  final String title;
  final String description;
  final ScheduleType scheduleType;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;
  final String? location;
  final bool isRecurring;
  final List<int> recurringDays;
  final int reminderMinutes;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScheduleModel copyWith({
    String? title,
    String? description,
    ScheduleType? scheduleType,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    Color? color,
    String? location,
    bool? isRecurring,
    List<int>? recurringDays,
    int? reminderMinutes,
    bool? isCompleted,
    DateTime? updatedAt,
  }) {
    return ScheduleModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduleType: scheduleType ?? this.scheduleType,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      location: location ?? this.location,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringDays: recurringDays ?? this.recurringDays,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'scheduleType': scheduleType.index,
    'date': date.toIso8601String(),
    'startHour': startTime.hour,
    'startMinute': startTime.minute,
    'endHour': endTime.hour,
    'endMinute': endTime.minute,
    'color': color.value,
    'location': location,
    'isRecurring': isRecurring,
    'recurringDays': recurringDays,
    'reminderMinutes': reminderMinutes,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      scheduleType: ScheduleType.values[map['scheduleType'] as int? ?? 0],
      date: DateTime.parse(map['date'] as String),
      startTime: TimeOfDay(
        hour: map['startHour'] as int,
        minute: map['startMinute'] as int,
      ),
      endTime: TimeOfDay(
        hour: map['endHour'] as int,
        minute: map['endMinute'] as int,
      ),
      color: Color(map['color'] as int),
      location: map['location'] as String?,
      isRecurring: map['isRecurring'] as bool? ?? false,
      recurringDays: List<int>.from(map['recurringDays'] as List<dynamic>? ?? []),
      reminderMinutes: map['reminderMinutes'] as int? ?? 15,
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory ScheduleModel.fromJson(Map<String, dynamic> json) => ScheduleModel.fromMap(json);

  /// Check if this schedule conflicts with another
  bool conflictsWith(ScheduleModel other) {
    // Check if on same date or recurring days overlap
    bool datesOverlap = false;
    
    if (isRecurring && other.isRecurring) {
      datesOverlap = recurringDays.any((d) => other.recurringDays.contains(d));
    } else if (isRecurring) {
      datesOverlap = recurringDays.contains(other.date.weekday);
    } else if (other.isRecurring) {
      datesOverlap = other.recurringDays.contains(date.weekday);
    } else {
      datesOverlap = date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day;
    }

    if (!datesOverlap) return false;

    // Check time overlap
    final thisStart = startTime.hour * 60 + startTime.minute;
    final thisEnd = endTime.hour * 60 + endTime.minute;
    final otherStart = other.startTime.hour * 60 + other.startTime.minute;
    final otherEnd = other.endTime.hour * 60 + other.endTime.minute;

    return thisStart < otherEnd && thisEnd > otherStart;
  }
}

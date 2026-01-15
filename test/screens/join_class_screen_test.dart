import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/models/class.dart';
import 'package:smart_scheduler/services/schedule_conflict_service.dart';

// Note: Full widget tests for JoinClassScreen would require mocking
// Firebase and providers. These are unit tests for the conflict detection logic.

void main() {
  group('JoinClassScreen - Student Conflict Warning', () {
    // Property 10: Student Conflict Warning Allows Join
    // When a student joins a class that conflicts with enrolled classes,
    // a warning should be shown but the join should still be allowed
    
    test('conflict detection works for student enrolled classes', () {
      // Simulate enrolled classes
      final enrolledClasses = [
        _createTestClass(
          id: 'enrolled1',
          name: 'English 101',
          days: [1, 3, 5], // Mon, Wed, Fri
          startHour: 9,
          endHour: 10,
        ),
        _createTestClass(
          id: 'enrolled2',
          name: 'History 201',
          days: [2, 4], // Tue, Thu
          startHour: 14,
          endHour: 16,
        ),
      ];

      // New class that conflicts with English 101
      final newClass = _createTestClass(
        id: 'new1',
        name: 'Math 101',
        days: [1, 3], // Mon, Wed - overlaps with English 101
        startHour: 9,
        startMinute: 30,
        endHour: 10,
        endMinute: 30,
      );

      final conflicts = ScheduleConflictService.findConflicts(
        startTime: newClass.startTime,
        endTime: newClass.endTime,
        daysOfWeek: newClass.daysOfWeek,
        existingClasses: enrolledClasses,
      );

      expect(conflicts.length, equals(1));
      expect(conflicts.first.name, equals('English 101'));
    });

    test('no conflict when new class does not overlap with enrolled classes', () {
      final enrolledClasses = [
        _createTestClass(
          id: 'enrolled1',
          name: 'English 101',
          days: [1, 3, 5],
          startHour: 9,
          endHour: 10,
        ),
      ];

      // New class on different time
      final newClass = _createTestClass(
        id: 'new1',
        name: 'Math 101',
        days: [1, 3, 5],
        startHour: 14,
        endHour: 15,
      );

      final conflicts = ScheduleConflictService.findConflicts(
        startTime: newClass.startTime,
        endTime: newClass.endTime,
        daysOfWeek: newClass.daysOfWeek,
        existingClasses: enrolledClasses,
      );

      expect(conflicts, isEmpty);
    });

    test('no conflict when new class is on different days', () {
      final enrolledClasses = [
        _createTestClass(
          id: 'enrolled1',
          name: 'English 101',
          days: [1, 3, 5], // Mon, Wed, Fri
          startHour: 9,
          endHour: 10,
        ),
      ];

      // New class on Tue, Thu
      final newClass = _createTestClass(
        id: 'new1',
        name: 'Math 101',
        days: [2, 4],
        startHour: 9,
        endHour: 10,
      );

      final conflicts = ScheduleConflictService.findConflicts(
        startTime: newClass.startTime,
        endTime: newClass.endTime,
        daysOfWeek: newClass.daysOfWeek,
        existingClasses: enrolledClasses,
      );

      expect(conflicts, isEmpty);
    });

    test('detects multiple conflicts with enrolled classes', () {
      final enrolledClasses = [
        _createTestClass(
          id: 'enrolled1',
          name: 'English 101',
          days: [1, 3],
          startHour: 9,
          endHour: 10,
        ),
        _createTestClass(
          id: 'enrolled2',
          name: 'Science 101',
          days: [1, 3],
          startHour: 10,
          endHour: 11,
        ),
      ];

      // New class that spans both enrolled classes
      final newClass = _createTestClass(
        id: 'new1',
        name: 'Math 101',
        days: [1, 3],
        startHour: 9,
        endHour: 11,
      );

      final conflicts = ScheduleConflictService.findConflicts(
        startTime: newClass.startTime,
        endTime: newClass.endTime,
        daysOfWeek: newClass.daysOfWeek,
        existingClasses: enrolledClasses,
      );

      expect(conflicts.length, equals(2));
      expect(conflicts.map((c) => c.name), containsAll(['English 101', 'Science 101']));
    });
  });
}

/// Helper function to create test ClassModel instances
ClassModel _createTestClass({
  required String id,
  required String name,
  required List<int> days,
  required int startHour,
  required int endHour,
  int startMinute = 0,
  int endMinute = 0,
}) {
  return ClassModel(
    id: id,
    userId: 'test-user',
    name: name,
    daysOfWeek: days,
    startTime: TimeOfDay(hour: startHour, minute: startMinute),
    endTime: TimeOfDay(hour: endHour, minute: endMinute),
    instructorOrRoom: '',
    location: '',
    color: Colors.blue,
    alerts: [],
    isModifiedLocally: false,
  );
}

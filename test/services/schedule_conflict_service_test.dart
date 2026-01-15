import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/models/class.dart';
import 'package:smart_scheduler/services/schedule_conflict_service.dart';

void main() {
  group('ScheduleConflictService', () {
    group('timesOverlap', () {
      // Property 6: Conflict Detection Accuracy - Time overlap tests
      test('returns true when times overlap (startA < endB AND endA > startB)', () {
        // Class A: 9:00-11:00, Class B: 10:00-12:00 (overlap 10:00-11:00)
        expect(
          ScheduleConflictService.timesOverlap(
            const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 11, minute: 0),
            const TimeOfDay(hour: 10, minute: 0),
            const TimeOfDay(hour: 12, minute: 0),
          ),
          isTrue,
        );
      });

      test('returns true when one class is completely inside another', () {
        // Class A: 9:00-14:00, Class B: 10:00-12:00 (B inside A)
        expect(
          ScheduleConflictService.timesOverlap(
            const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 14, minute: 0),
            const TimeOfDay(hour: 10, minute: 0),
            const TimeOfDay(hour: 12, minute: 0),
          ),
          isTrue,
        );
      });

      test('returns true when times are identical', () {
        expect(
          ScheduleConflictService.timesOverlap(
            const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 10, minute: 0),
            const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 10, minute: 0),
          ),
          isTrue,
        );
      });

      // Property 7: Adjacent Times Non-Conflicting
      test('returns false when times are exactly adjacent (9:00-10:00 and 10:00-11:00)', () {
        expect(
          ScheduleConflictService.timesOverlap(
            const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 10, minute: 0),
            const TimeOfDay(hour: 10, minute: 0),
            const TimeOfDay(hour: 11, minute: 0),
          ),
          isFalse,
        );
      });

      test('returns false when times are adjacent in reverse order', () {
        expect(
          ScheduleConflictService.timesOverlap(
            const TimeOfDay(hour: 10, minute: 0),
            const TimeOfDay(hour: 11, minute: 0),
            const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 10, minute: 0),
          ),
          isFalse,
        );
      });

      // Property 8: Same Day Non-Overlapping Times Non-Conflicting
      test('returns false when times do not overlap (9:00-10:00 and 14:00-15:00)', () {
        expect(
          ScheduleConflictService.timesOverlap(
            const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 10, minute: 0),
            const TimeOfDay(hour: 14, minute: 0),
            const TimeOfDay(hour: 15, minute: 0),
          ),
          isFalse,
        );
      });

      test('returns false when times are completely separate', () {
        // Morning class vs afternoon class
        expect(
          ScheduleConflictService.timesOverlap(
            const TimeOfDay(hour: 8, minute: 0),
            const TimeOfDay(hour: 9, minute: 30),
            const TimeOfDay(hour: 13, minute: 0),
            const TimeOfDay(hour: 14, minute: 30),
          ),
          isFalse,
        );
      });

      test('handles minute-level precision correctly', () {
        // 9:00-9:30 and 9:15-9:45 should overlap
        expect(
          ScheduleConflictService.timesOverlap(
            const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 9, minute: 30),
            const TimeOfDay(hour: 9, minute: 15),
            const TimeOfDay(hour: 9, minute: 45),
          ),
          isTrue,
        );
      });
    });

    group('daysOverlap', () {
      test('returns true when days share at least one common day', () {
        expect(
          ScheduleConflictService.daysOverlap([1, 3, 5], [3, 4]),
          isTrue,
        );
      });

      test('returns true when days are identical', () {
        expect(
          ScheduleConflictService.daysOverlap([1, 3, 5], [1, 3, 5]),
          isTrue,
        );
      });

      test('returns false when days have no overlap', () {
        expect(
          ScheduleConflictService.daysOverlap([1, 3, 5], [2, 4, 6]),
          isFalse,
        );
      });

      test('returns false when one list is empty', () {
        expect(
          ScheduleConflictService.daysOverlap([], [1, 2, 3]),
          isFalse,
        );
      });

      test('returns false when both lists are empty', () {
        expect(
          ScheduleConflictService.daysOverlap([], []),
          isFalse,
        );
      });
    });

    group('findConflicts', () {
      late List<ClassModel> existingClasses;

      setUp(() {
        existingClasses = [
          _createTestClass(
            id: 'class1',
            name: 'Math 101',
            days: [1, 3, 5], // Mon, Wed, Fri
            startHour: 9,
            endHour: 10,
          ),
          _createTestClass(
            id: 'class2',
            name: 'Physics 201',
            days: [2, 4], // Tue, Thu
            startHour: 14,
            endHour: 16,
          ),
          _createTestClass(
            id: 'class3',
            name: 'Chemistry 101',
            days: [1, 3], // Mon, Wed
            startHour: 11,
            endHour: 12,
          ),
        ];
      });

      test('returns empty list when no conflicts exist', () {
        final conflicts = ScheduleConflictService.findConflicts(
          startTime: const TimeOfDay(hour: 13, minute: 0),
          endTime: const TimeOfDay(hour: 14, minute: 0),
          daysOfWeek: [1, 3, 5],
          existingClasses: existingClasses,
        );

        expect(conflicts, isEmpty);
      });

      test('detects conflict when times and days overlap', () {
        // Trying to schedule 9:30-10:30 on Mon/Wed/Fri - conflicts with Math 101
        final conflicts = ScheduleConflictService.findConflicts(
          startTime: const TimeOfDay(hour: 9, minute: 30),
          endTime: const TimeOfDay(hour: 10, minute: 30),
          daysOfWeek: [1, 3, 5],
          existingClasses: existingClasses,
        );

        expect(conflicts.length, equals(1));
        expect(conflicts.first.name, equals('Math 101'));
      });

      test('detects multiple conflicts', () {
        // Trying to schedule 9:00-12:00 on Mon/Wed - conflicts with Math 101 and Chemistry 101
        final conflicts = ScheduleConflictService.findConflicts(
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 12, minute: 0),
          daysOfWeek: [1, 3],
          existingClasses: existingClasses,
        );

        expect(conflicts.length, equals(2));
        expect(conflicts.map((c) => c.name), containsAll(['Math 101', 'Chemistry 101']));
      });

      test('does not detect conflict when only days overlap but times do not', () {
        // Same days as Math 101 but different time
        final conflicts = ScheduleConflictService.findConflicts(
          startTime: const TimeOfDay(hour: 14, minute: 0),
          endTime: const TimeOfDay(hour: 15, minute: 0),
          daysOfWeek: [1, 3, 5],
          existingClasses: existingClasses,
        );

        expect(conflicts, isEmpty);
      });

      test('does not detect conflict when only times overlap but days do not', () {
        // Same time as Math 101 but different days
        final conflicts = ScheduleConflictService.findConflicts(
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 10, minute: 0),
          daysOfWeek: [2, 4], // Tue, Thu
          existingClasses: existingClasses,
        );

        expect(conflicts, isEmpty);
      });

      // Property 2: Self-Exclusion When Editing
      test('excludes class being edited from conflict check', () {
        // Same schedule as Math 101, but excluding Math 101
        final conflicts = ScheduleConflictService.findConflicts(
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 10, minute: 0),
          daysOfWeek: [1, 3, 5],
          existingClasses: existingClasses,
          excludeClassId: 'class1', // Exclude Math 101
        );

        expect(conflicts, isEmpty);
      });

      test('still detects other conflicts when excluding one class', () {
        // Schedule that conflicts with both Math 101 and Chemistry 101
        // But we're editing Math 101, so only Chemistry 101 should be detected
        final conflicts = ScheduleConflictService.findConflicts(
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 12, minute: 0),
          daysOfWeek: [1, 3],
          existingClasses: existingClasses,
          excludeClassId: 'class1',
        );

        expect(conflicts.length, equals(1));
        expect(conflicts.first.name, equals('Chemistry 101'));
      });

      test('returns empty list when existing classes is empty', () {
        final conflicts = ScheduleConflictService.findConflicts(
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 10, minute: 0),
          daysOfWeek: [1, 3, 5],
          existingClasses: [],
        );

        expect(conflicts, isEmpty);
      });
    });

    group('formatConflictMessage', () {
      test('returns empty string when no conflicts', () {
        final message = ScheduleConflictService.formatConflictMessage([], [1, 3, 5]);
        expect(message, isEmpty);
      });

      test('includes class name in message', () {
        final conflicts = [
          _createTestClass(
            id: 'class1',
            name: 'Math 101',
            days: [1, 3, 5],
            startHour: 9,
            endHour: 10,
          ),
        ];

        final message = ScheduleConflictService.formatConflictMessage(conflicts, [1, 3]);
        expect(message, contains('Math 101'));
      });

      test('includes time range in message', () {
        final conflicts = [
          _createTestClass(
            id: 'class1',
            name: 'Math 101',
            days: [1, 3, 5],
            startHour: 9,
            endHour: 10,
          ),
        ];

        final message = ScheduleConflictService.formatConflictMessage(conflicts, [1, 3]);
        expect(message, contains('9:00 AM'));
        expect(message, contains('10:00 AM'));
      });

      test('includes overlapping days in message', () {
        final conflicts = [
          _createTestClass(
            id: 'class1',
            name: 'Math 101',
            days: [1, 3, 5], // Mon, Wed, Fri
            startHour: 9,
            endHour: 10,
          ),
        ];

        // Proposed days are Mon, Wed (1, 3)
        final message = ScheduleConflictService.formatConflictMessage(conflicts, [1, 3]);
        expect(message, contains('Mon'));
        expect(message, contains('Wed'));
      });

      test('lists all conflicting classes', () {
        final conflicts = [
          _createTestClass(
            id: 'class1',
            name: 'Math 101',
            days: [1, 3],
            startHour: 9,
            endHour: 10,
          ),
          _createTestClass(
            id: 'class2',
            name: 'Physics 201',
            days: [1, 3],
            startHour: 9,
            endHour: 10,
          ),
        ];

        final message = ScheduleConflictService.formatConflictMessage(conflicts, [1, 3]);
        expect(message, contains('Math 101'));
        expect(message, contains('Physics 201'));
      });
    });

    group('getOverlappingDays', () {
      test('returns common days between two lists', () {
        final overlapping = ScheduleConflictService.getOverlappingDays([1, 3, 5], [3, 4, 5]);
        expect(overlapping, containsAll([3, 5]));
        expect(overlapping.length, equals(2));
      });

      test('returns empty list when no overlap', () {
        final overlapping = ScheduleConflictService.getOverlappingDays([1, 3, 5], [2, 4, 6]);
        expect(overlapping, isEmpty);
      });
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

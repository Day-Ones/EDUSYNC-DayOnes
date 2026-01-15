import 'package:flutter/material.dart';
import '../models/class.dart';

/// Service for detecting schedule conflicts between classes
class ScheduleConflictService {
  /// Check if two time ranges overlap
  /// Adjacent times (e.g., 9:00-10:00 and 10:00-11:00) are NOT considered overlapping
  /// 
  /// Returns true if the time ranges overlap, false otherwise
  static bool timesOverlap(
    TimeOfDay startA,
    TimeOfDay endA,
    TimeOfDay startB,
    TimeOfDay endB,
  ) {
    // Convert to minutes for easier comparison
    final startAMinutes = startA.hour * 60 + startA.minute;
    final endAMinutes = endA.hour * 60 + endA.minute;
    final startBMinutes = startB.hour * 60 + startB.minute;
    final endBMinutes = endB.hour * 60 + endB.minute;

    // Times overlap when: startA < endB AND endA > startB
    // Using < and > (not <= and >=) means adjacent times don't overlap
    return startAMinutes < endBMinutes && endAMinutes > startBMinutes;
  }

  /// Check if two day lists share any common days
  /// 
  /// Returns true if there's at least one common day, false otherwise
  static bool daysOverlap(List<int> daysA, List<int> daysB) {
    return daysA.any((day) => daysB.contains(day));
  }

  /// Find all classes that conflict with the proposed schedule
  /// 
  /// Parameters:
  /// - [startTime]: Proposed start time
  /// - [endTime]: Proposed end time
  /// - [daysOfWeek]: Proposed days (1=Monday, 7=Sunday)
  /// - [existingClasses]: List of existing classes to check against
  /// - [excludeClassId]: Optional class ID to exclude (for editing scenarios)
  /// 
  /// Returns a list of conflicting ClassModel objects
  static List<ClassModel> findConflicts({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required List<int> daysOfWeek,
    required List<ClassModel> existingClasses,
    String? excludeClassId,
  }) {
    final conflicts = <ClassModel>[];

    for (final existingClass in existingClasses) {
      // Skip the class being edited
      if (excludeClassId != null && existingClass.id == excludeClassId) {
        continue;
      }

      // Check if days overlap
      if (!daysOverlap(daysOfWeek, existingClass.daysOfWeek)) {
        continue;
      }

      // Check if times overlap
      if (timesOverlap(
        startTime,
        endTime,
        existingClass.startTime,
        existingClass.endTime,
      )) {
        conflicts.add(existingClass);
      }
    }

    return conflicts;
  }

  /// Get the overlapping days between two day lists
  static List<int> getOverlappingDays(List<int> daysA, List<int> daysB) {
    return daysA.where((day) => daysB.contains(day)).toList();
  }

  /// Format a single conflict for display
  static String _formatSingleConflict(ClassModel conflict, List<int> proposedDays) {
    final overlappingDays = getOverlappingDays(proposedDays, conflict.daysOfWeek);
    final dayNames = _formatDayNames(overlappingDays);
    final timeRange = '${_formatTime(conflict.startTime)} - ${_formatTime(conflict.endTime)}';
    
    return '• ${conflict.name} ($dayNames, $timeRange)';
  }

  /// Format conflict information for display
  /// 
  /// Returns a formatted string describing all conflicts
  static String formatConflictMessage(List<ClassModel> conflicts, List<int> proposedDays) {
    if (conflicts.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('Schedule conflicts with:');
    
    for (final conflict in conflicts) {
      buffer.writeln(_formatSingleConflict(conflict, proposedDays));
    }

    return buffer.toString().trim();
  }

  /// Format day numbers to readable names
  static String _formatDayNames(List<int> days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sortedDays = List<int>.from(days)..sort();
    return sortedDays.map((d) => dayNames[d - 1]).join(', ');
  }

  /// Format TimeOfDay to readable string
  static String _formatTime(TimeOfDay time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

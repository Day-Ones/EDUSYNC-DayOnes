import '../models/class.dart';
import '../models/attendance.dart';

/// Service for handling attendance time validation and status calculation
class AttendanceTimeService {
  /// Check if current time is within the check-in window for a class
  /// Students can check in 15 minutes before class starts until the absent grace period ends
  static bool canCheckIn(ClassModel classModel, DateTime now) {
    final classStartToday = _getClassStartTime(classModel, now);

    if (classStartToday == null) {
      // Class doesn't occur today
      return false;
    }

    // Check-in window: 15 minutes before class start
    final checkInWindowStart =
        classStartToday.subtract(const Duration(minutes: 15));

    // Check-in window ends at: class start + absent grace period
    final checkInWindowEnd = classStartToday
        .add(Duration(minutes: classModel.absentGracePeriodMinutes));

    return now.isAfter(checkInWindowStart) && now.isBefore(checkInWindowEnd);
  }

  /// Calculate the attendance status based on check-in time
  static AttendanceStatus calculateStatus(
      ClassModel classModel, DateTime checkedInAt) {
    final classStartTime = _getClassStartTime(classModel, checkedInAt);

    if (classStartTime == null) {
      return AttendanceStatus.absent;
    }

    // If checked in before or within late grace period: Present
    final lateThreshold = classStartTime
        .add(Duration(minutes: classModel.lateGracePeriodMinutes));

    print('DEBUG: Class start time: $classStartTime');
    print('DEBUG: Checked in at: $checkedInAt');
    print(
        'DEBUG: Late threshold: $lateThreshold (${classModel.lateGracePeriodMinutes} min grace)');
    print(
        'DEBUG: Absent threshold: ${classStartTime.add(Duration(minutes: classModel.absentGracePeriodMinutes))} (${classModel.absentGracePeriodMinutes} min grace)');

    if (checkedInAt.isBefore(lateThreshold) ||
        checkedInAt.isAtSameMomentAs(lateThreshold)) {
      print('DEBUG: Status = PRESENT (checked in before/at $lateThreshold)');
      return AttendanceStatus.present;
    }

    // If checked in after late grace but before absent grace: Late
    final absentThreshold = classStartTime
        .add(Duration(minutes: classModel.absentGracePeriodMinutes));

    if (checkedInAt.isBefore(absentThreshold)) {
      print(
          'DEBUG: Status = LATE (checked in after $lateThreshold but before $absentThreshold)');
      return AttendanceStatus.late;
    }

    // After absent grace period: Absent (shouldn't happen if validation is correct)
    print('DEBUG: Status = ABSENT (checked in after $absentThreshold)');
    return AttendanceStatus.absent;
  }

  /// Check if QR code generation is allowed for the class
  /// Faculty can't generate QR after the absent grace period ends
  static bool canGenerateQR(ClassModel classModel, DateTime now) {
    final classStartToday = _getClassStartTime(classModel, now);

    if (classStartToday == null) {
      // Class doesn't occur today
      return false;
    }

    final qrWindowEnd = classStartToday
        .add(Duration(minutes: classModel.absentGracePeriodMinutes));

    return now.isBefore(qrWindowEnd);
  }

  /// Get the time remaining until check-in window opens
  /// Returns null if window is open or class doesn't occur today
  static Duration? getTimeUntilCheckInOpens(
      ClassModel classModel, DateTime now) {
    final classStartToday = _getClassStartTime(classModel, now);

    if (classStartToday == null) {
      return null;
    }

    final checkInWindowStart =
        classStartToday.subtract(const Duration(minutes: 15));

    if (now.isBefore(checkInWindowStart)) {
      return checkInWindowStart.difference(now);
    }

    return null; // Window is already open or closed
  }

  /// Get the time remaining until check-in window closes
  /// Returns null if window is closed or class doesn't occur today
  static Duration? getTimeUntilCheckInCloses(
      ClassModel classModel, DateTime now) {
    final classStartToday = _getClassStartTime(classModel, now);

    if (classStartToday == null) {
      return null;
    }

    final checkInWindowEnd = classStartToday
        .add(Duration(minutes: classModel.absentGracePeriodMinutes));

    if (now.isBefore(checkInWindowEnd)) {
      return checkInWindowEnd.difference(now);
    }

    return null; // Window is closed
  }

  /// Get formatted message about check-in window status
  static String getCheckInWindowMessage(ClassModel classModel, DateTime now) {
    if (!_isClassToday(classModel, now)) {
      return 'This class does not occur today';
    }

    final classStartToday = _getClassStartTime(classModel, now)!;
    final checkInWindowStart =
        classStartToday.subtract(const Duration(minutes: 15));
    final checkInWindowEnd = classStartToday
        .add(Duration(minutes: classModel.absentGracePeriodMinutes));

    if (now.isBefore(checkInWindowStart)) {
      final duration = getTimeUntilCheckInOpens(classModel, now)!;
      return 'Check-in opens in ${_formatDuration(duration)}';
    } else if (now.isAfter(checkInWindowEnd)) {
      return 'Check-in window has closed';
    } else {
      final duration = getTimeUntilCheckInCloses(classModel, now)!;
      final classStarted = now.isAfter(classStartToday);

      if (classStarted) {
        final lateThreshold = classStartToday
            .add(Duration(minutes: classModel.lateGracePeriodMinutes));
        if (now.isBefore(lateThreshold)) {
          return 'Check-in now (Grace period: ${_formatDuration(lateThreshold.difference(now))})';
        } else {
          return 'Check-in now (Will be marked late)';
        }
      } else {
        return 'Check-in window open (${_formatDuration(duration)} remaining)';
      }
    }
  }

  /// Helper: Get the class start time for today
  static DateTime? _getClassStartTime(ClassModel classModel, DateTime now) {
    if (!_isClassToday(classModel, now)) {
      return null;
    }

    return DateTime(
      now.year,
      now.month,
      now.day,
      classModel.startTime.hour,
      classModel.startTime.minute,
    );
  }

  /// Helper: Check if class occurs today
  static bool _isClassToday(ClassModel classModel, DateTime now) {
    // Convert DateTime.weekday (1=Monday, 7=Sunday) to match daysOfWeek
    return classModel.daysOfWeek.contains(now.weekday);
  }

  /// Helper: Format duration for display
  static String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

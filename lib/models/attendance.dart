/// Attendance status enum
enum AttendanceStatus {
  present,
  late,
  absent,
}

/// Represents a single attendance record for a student in a class
class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.checkedInAt,
    this.status = AttendanceStatus.present,
  });

  final String id;
  final String classId;
  final String studentId;
  final String studentName;
  final DateTime date;
  final DateTime checkedInAt;
  final AttendanceStatus status;

  Map<String, dynamic> toMap() => {
        'id': id,
        'classId': classId,
        'studentId': studentId,
        'studentName': studentName,
        'date': date.toIso8601String(),
        'checkedInAt': checkedInAt.toIso8601String(),
        'status': status.name,
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as String,
      classId: map['classId'] as String,
      studentId: map['studentId'] as String,
      studentName: map['studentName'] as String? ?? 'Unknown',
      date: DateTime.parse(map['date'] as String),
      checkedInAt: DateTime.parse(map['checkedInAt'] as String),
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String?),
        orElse: () => AttendanceStatus.present,
      ),
    );
  }
}

/// Represents a student enrolled in a class with their attendance stats
class EnrolledStudent {
  EnrolledStudent({
    required this.id,
    required this.name,
    required this.email,
    this.studentId,
    this.totalClasses = 0,
    this.attendedClasses = 0,
    this.isCheckedInToday = false,
    this.todayStatus,
    this.checkedInTime,
  });

  final String id;
  final String name;
  final String email;
  final String? studentId;
  final int totalClasses;
  final int attendedClasses;
  final bool isCheckedInToday;
  final AttendanceStatus? todayStatus;
  final DateTime? checkedInTime;

  double get attendancePercentage =>
      totalClasses > 0 ? (attendedClasses / totalClasses) * 100 : 0;

  EnrolledStudent copyWith({
    int? totalClasses,
    int? attendedClasses,
    bool? isCheckedInToday,
    AttendanceStatus? todayStatus,
    DateTime? checkedInTime,
  }) {
    return EnrolledStudent(
      id: id,
      name: name,
      email: email,
      studentId: studentId,
      totalClasses: totalClasses ?? this.totalClasses,
      attendedClasses: attendedClasses ?? this.attendedClasses,
      isCheckedInToday: isCheckedInToday ?? this.isCheckedInToday,
      todayStatus: todayStatus ?? this.todayStatus,
      checkedInTime: checkedInTime ?? this.checkedInTime,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'studentId': studentId,
        'totalClasses': totalClasses,
        'attendedClasses': attendedClasses,
        'isCheckedInToday': isCheckedInToday,
      };

  factory EnrolledStudent.fromMap(Map<String, dynamic> map) {
    return EnrolledStudent(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Unknown',
      email: map['email'] as String? ?? '',
      studentId: map['studentId'] as String?,
      totalClasses: map['totalClasses'] as int? ?? 0,
      attendedClasses: map['attendedClasses'] as int? ?? 0,
      isCheckedInToday: map['isCheckedInToday'] as bool? ?? false,
    );
  }
}

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';

class AttendanceProvider extends ChangeNotifier {
  final Map<String, List<AttendanceRecord>> _attendanceByClass = {};
  final Map<String, List<EnrolledStudent>> _studentsByClass = {};
  final Map<String, String> _activeQrCodes = {}; // classId -> qrCode
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<AttendanceRecord> getAttendanceForClass(String classId) {
    return _attendanceByClass[classId] ?? [];
  }

  List<EnrolledStudent> getStudentsForClass(String classId) {
    return _studentsByClass[classId] ?? [];
  }

  List<EnrolledStudent> getStudentsNotCheckedIn(String classId) {
    return getStudentsForClass(classId).where((s) => !s.isCheckedInToday).toList();
  }

  String? getActiveQrCode(String classId) {
    return _activeQrCodes[classId];
  }

  /// Generate a QR code for attendance check-in
  String generateAttendanceQr(String classId, String className) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    final qrData = jsonEncode({
      'classId': classId,
      'className': className,
      'timestamp': timestamp,
      'code': random,
      'type': 'attendance',
    });
    _activeQrCodes[classId] = qrData;
    notifyListeners();
    return qrData;
  }

  /// Validate and process a scanned QR code
  Future<Map<String, dynamic>> processAttendanceQr(
    String qrData,
    String studentId,
    String studentName,
  ) async {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      
      if (data['type'] != 'attendance') {
        return {'success': false, 'message': 'Invalid QR code'};
      }

      final classId = data['classId'] as String;
      final className = data['className'] as String;
      final timestamp = data['timestamp'] as int;
      
      // Check if QR code is still valid (within 5 minutes)
      final qrTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      if (now.difference(qrTime).inMinutes > 5) {
        return {'success': false, 'message': 'QR code has expired'};
      }

      // Check if already checked in today
      final today = DateTime(now.year, now.month, now.day);
      final existingRecord = _attendanceByClass[classId]?.any((r) =>
        r.studentId == studentId &&
        r.date.year == today.year &&
        r.date.month == today.month &&
        r.date.day == today.day
      ) ?? false;

      if (existingRecord) {
        return {'success': false, 'message': 'Already checked in today'};
      }

      // Create attendance record
      final record = AttendanceRecord(
        id: '${classId}_${studentId}_${now.millisecondsSinceEpoch}',
        classId: classId,
        studentId: studentId,
        studentName: studentName,
        date: today,
        checkedInAt: now,
      );

      _attendanceByClass.putIfAbsent(classId, () => []);
      _attendanceByClass[classId]!.add(record);

      // Update student's checked-in status
      _updateStudentCheckedInStatus(classId, studentId, true);

      await _saveAttendance();
      notifyListeners();

      return {
        'success': true,
        'message': 'Checked in to $className',
        'className': className,
      };
    } catch (e) {
      return {'success': false, 'message': 'Invalid QR code format'};
    }
  }

  void _updateStudentCheckedInStatus(String classId, String studentId, bool isCheckedIn) {
    final students = _studentsByClass[classId];
    if (students != null) {
      final index = students.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        _studentsByClass[classId]![index] = students[index].copyWith(
          isCheckedInToday: isCheckedIn,
          attendedClasses: isCheckedIn 
              ? students[index].attendedClasses + 1 
              : students[index].attendedClasses,
        );
      }
    }
  }

  /// Load students for a class from Firestore
  Future<void> loadStudentsForClass(String classId, List<String> studentIds) async {
    await _loadAttendance();
    
    if (studentIds.isEmpty) {
      _studentsByClass[classId] = [];
      notifyListeners();
      return;
    }
    
    final students = <EnrolledStudent>[];
    
    // Fetch student data from Firestore
    for (final studentId in studentIds) {
      try {
        final userDoc = await _firestore.collection('users').doc(studentId).get();
        
        String name = 'Unknown Student';
        String email = 'unknown@school.edu';
        String? studentIdNum;
        
        if (userDoc.exists) {
          final data = userDoc.data()!;
          name = data['fullName'] as String? ?? 'Unknown Student';
          email = data['email'] as String? ?? 'unknown@school.edu';
          studentIdNum = data['studentId'] as String?;
        }
        
        // Check if checked in today
        final today = DateTime.now();
        final isCheckedIn = _attendanceByClass[classId]?.any((r) =>
          r.studentId == studentId &&
          r.date.year == today.year &&
          r.date.month == today.month &&
          r.date.day == today.day
        ) ?? false;

        // Count total attendance
        final attendedCount = _attendanceByClass[classId]
            ?.where((r) => r.studentId == studentId)
            .length ?? 0;

        students.add(EnrolledStudent(
          id: studentId,
          name: name,
          email: email,
          studentId: studentIdNum,
          totalClasses: 10, // This should be calculated based on class schedule
          attendedClasses: attendedCount,
          isCheckedInToday: isCheckedIn,
        ));
      } catch (e) {
        debugPrint('Error fetching student $studentId: $e');
        // Add placeholder if fetch fails
        students.add(EnrolledStudent(
          id: studentId,
          name: 'Student',
          email: 'student@school.edu',
          totalClasses: 10,
          attendedClasses: 0,
          isCheckedInToday: false,
        ));
      }
    }

    _studentsByClass[classId] = students;
    notifyListeners();
  }

  /// Reset daily check-in status (call at start of each day)
  void resetDailyCheckIn(String classId) {
    final students = _studentsByClass[classId];
    if (students != null) {
      _studentsByClass[classId] = students.map((s) => 
        s.copyWith(isCheckedInToday: false)
      ).toList();
      notifyListeners();
    }
  }

  /// Increment total classes count (call when a class session occurs)
  void incrementTotalClasses(String classId) {
    final students = _studentsByClass[classId];
    if (students != null) {
      _studentsByClass[classId] = students.map((s) => 
        s.copyWith(totalClasses: s.totalClasses + 1)
      ).toList();
      _saveAttendance();
      notifyListeners();
    }
  }

  Future<void> _loadAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('attendance_records');
    if (data != null) {
      final Map<String, dynamic> decoded = jsonDecode(data);
      decoded.forEach((classId, records) {
        _attendanceByClass[classId] = (records as List)
            .map((r) => AttendanceRecord.fromMap(r as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _saveAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    _attendanceByClass.forEach((classId, records) {
      data[classId] = records.map((r) => r.toMap()).toList();
    });
    await prefs.setString('attendance_records', jsonEncode(data));
  }
}

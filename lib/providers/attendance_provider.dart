import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';
import '../models/class.dart';
import '../services/firebase_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;

  AttendanceProvider(this._firebaseService);

  final Map<String, List<AttendanceRecord>> _attendanceByClass = {};
  final Map<String, List<EnrolledStudent>> _studentsByClass = {};
  final Map<String, String> _activeQrCodes = {}; // classId -> qrCode
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _pendingSyncCount = 0;
  StreamSubscription<QuerySnapshot>? _attendanceListener;

  int get pendingSyncCount => _pendingSyncCount;

  List<AttendanceRecord> getAttendanceForClass(String classId) {
    return _attendanceByClass[classId] ?? [];
  }

  List<EnrolledStudent> getStudentsForClass(String classId) {
    return _studentsByClass[classId] ?? [];
  }

  List<EnrolledStudent> getStudentsNotCheckedIn(String classId) {
    return getStudentsForClass(classId)
        .where((s) => !s.isCheckedInToday)
        .toList();
  }

  String? getActiveQrCode(String classId) {
    return _activeQrCodes[classId];
  }

  /// Generate a QR code for attendance check-in
  Future<String> generateAttendanceQr(
    String classId,
    String className,
    String facultyId,
    String facultyName,
  ) async {
    // Create QR session via Firebase service (handles offline storage)
    final sessionId = await _firebaseService.createAttendanceSession(
      classId: classId,
      className: className,
      facultyId: facultyId,
      facultyName: facultyName,
    );

    if (sessionId == null) {
      throw Exception('Failed to create QR session');
    }

    final qrData = jsonEncode({
      'sessionId': sessionId,
      'classId': classId,
      'className': className,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'attendance',
    });

    _activeQrCodes[classId] = qrData;
    notifyListeners();
    return qrData;
  }

  /// Sync pending QR codes (faculty)
  Future<void> syncPendingQrCodes() async {
    final count = await _firebaseService.syncPendingQrCodes();
    if (count > 0) {
      debugPrint('Synced $count QR codes');
    }
  }

  /// Validate and process a scanned QR code
  Future<Map<String, dynamic>> processAttendanceQr(
    String qrData,
    String studentId,
    String studentName,
    ClassModel classModel,
  ) async {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;

      if (data['type'] != 'attendance') {
        return {'success': false, 'message': 'Invalid QR code'};
      }

      final sessionId = data['sessionId'] as String;
      final classId = data['classId'] as String;
      final className = data['className'] as String;
      final timestamp = data['timestamp'] as int;

      // Check if QR code is still valid (within 5 minutes)
      final qrTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      if (now.difference(qrTime).inMinutes > 5) {
        return {'success': false, 'message': 'QR code has expired'};
      }

      // Record attendance via Firebase service (handles offline storage and status calculation)
      final result = await _firebaseService.recordAttendance(
        sessionId: sessionId,
        classId: classId,
        studentId: studentId,
        studentName: studentName,
        classModel: classModel,
      );

      if (result['success']) {
        // Update local cache with status
        final today = DateTime(now.year, now.month, now.day);
        final status = AttendanceStatus.values.firstWhere(
          (e) => e.name == (result['status'] as String? ?? 'present'),
          orElse: () => AttendanceStatus.present,
        );

        final record = AttendanceRecord(
          id: '${classId}_${studentId}_${now.millisecondsSinceEpoch}',
          classId: classId,
          studentId: studentId,
          studentName: studentName,
          date: today,
          checkedInAt: now,
          status: status,
        );

        _attendanceByClass.putIfAbsent(classId, () => []);
        _attendanceByClass[classId]!.add(record);
        _updateStudentCheckedInStatus(classId, studentId, true, status);
        await _saveAttendance();

        // Update pending count
        await _updatePendingCount();

        notifyListeners();
      }

      return {
        'success': result['success'],
        'message': result['message'],
        'className': className,
      };
    } catch (e) {
      return {'success': false, 'message': 'Invalid QR code format'};
    }
  }

  /// Sync pending attendance records (student)
  Future<void> syncPendingAttendance() async {
    final count = await _firebaseService.syncPendingAttendance();
    if (count > 0) {
      debugPrint('Synced $count attendance records');
      await _updatePendingCount();
      notifyListeners();
    }
  }

  /// Update pending sync count
  Future<void> _updatePendingCount() async {
    _pendingSyncCount = await _firebaseService.getPendingAttendanceCount();
  }

  void _updateStudentCheckedInStatus(
      String classId, String studentId, bool isCheckedIn,
      [AttendanceStatus? status]) {
    final students = _studentsByClass[classId];
    if (students != null) {
      final index = students.indexWhere((s) => s.id == studentId);
      if (index != -1) {
        _studentsByClass[classId]![index] = students[index].copyWith(
          isCheckedInToday: isCheckedIn,
          todayStatus: status,
          attendedClasses: isCheckedIn
              ? students[index].attendedClasses + 1
              : students[index].attendedClasses,
        );
      }
    }
  }

  /// Load students for a class from Firestore
  Future<void> loadStudentsForClass(
      String classId, List<String> studentIds) async {
    await _loadAttendance();

    if (studentIds.isEmpty) {
      _studentsByClass[classId] = [];
      notifyListeners();
      return;
    }

    final students = <EnrolledStudent>[];

    // Get today's date key for checking today's attendance
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Fetch student data from Firestore
    for (final studentId in studentIds) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(studentId).get();

        String name = 'Unknown Student';
        String email = 'unknown@school.edu';
        String? studentIdNum;

        if (userDoc.exists) {
          final data = userDoc.data()!;
          name = data['fullName'] as String? ?? 'Unknown Student';
          email = data['email'] as String? ?? 'unknown@school.edu';
          studentIdNum = data['studentId'] as String?;
        }

        // Check if checked in today from Firebase
        final todayRecordId = '${classId}_${studentId}_$dateKey';
        final todayAttendanceDoc = await _firestore
            .collection('attendance_records')
            .doc(todayRecordId)
            .get();
        final isCheckedIn = todayAttendanceDoc.exists;

        // Parse today's status and check-in time if checked in
        AttendanceStatus? todayStatus;
        DateTime? checkedInTime;
        if (isCheckedIn && todayAttendanceDoc.data() != null) {
          final attendanceData = todayAttendanceDoc.data()!;
          final statusStr = attendanceData['status'] as String?;
          todayStatus = statusStr != null
              ? AttendanceStatus.values.firstWhere(
                  (e) => e.name == statusStr,
                  orElse: () => AttendanceStatus.present,
                )
              : AttendanceStatus.present;
          final timestamp = attendanceData['checkedInAt'];
          if (timestamp is Timestamp) {
            checkedInTime = timestamp.toDate();
          }
        }

        // Count total attendance from Firebase
        final attendanceSnapshot = await _firestore
            .collection('attendance_records')
            .where('classId', isEqualTo: classId)
            .where('studentId', isEqualTo: studentId)
            .get();
        final attendedCount = attendanceSnapshot.docs.length;

        students.add(EnrolledStudent(
          id: studentId,
          name: name,
          email: email,
          studentId: studentIdNum,
          totalClasses: 10, // This should be calculated based on class schedule
          attendedClasses: attendedCount,
          isCheckedInToday: isCheckedIn,
          todayStatus: todayStatus,
          checkedInTime: checkedInTime,
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
      _studentsByClass[classId] =
          students.map((s) => s.copyWith(isCheckedInToday: false)).toList();
      notifyListeners();
    }
  }

  /// Increment total classes count (call when a class session occurs)
  void incrementTotalClasses(String classId) {
    final students = _studentsByClass[classId];
    if (students != null) {
      _studentsByClass[classId] = students
          .map((s) => s.copyWith(totalClasses: s.totalClasses + 1))
          .toList();
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

  /// Start listening for real-time attendance updates for a class
  void startListeningToAttendance(String classId, List<String> studentIds) {
    // Cancel previous listener if exists
    _attendanceListener?.cancel();

    // Get today's date
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Listen to today's attendance records for this class
    _attendanceListener = _firestore
        .collection('attendance_records')
        .where('classId', isEqualTo: classId)
        .where('date', isEqualTo: dateKey)
        .snapshots()
        .listen((snapshot) {
      // Update student list when attendance changes
      _updateStudentsFromFirebase(classId, studentIds, snapshot.docs);
    });
  }

  /// Update student attendance status from Firebase snapshot
  void _updateStudentsFromFirebase(
    String classId,
    List<String> studentIds,
    List<QueryDocumentSnapshot> attendanceDocs,
  ) {
    final students = _studentsByClass[classId];
    if (students == null || students.isEmpty) return;

    // Build a map of student attendance data
    final attendanceByStudent = <String, Map<String, dynamic>>{};
    for (final doc in attendanceDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final studentId = data['studentId'] as String;
      attendanceByStudent[studentId] = data;
    }

    // Update each student's check-in status, todayStatus, and checkedInTime
    bool hasChanges = false;
    final updatedStudents = students.map((student) {
      final attendanceData = attendanceByStudent[student.id];
      final isCheckedIn = attendanceData != null;

      if (isCheckedIn) {
        // Parse status
        final statusStr = attendanceData['status'] as String?;

        final todayStatus = statusStr != null
            ? AttendanceStatus.values.firstWhere(
                (e) => e.name == statusStr,
                orElse: () => AttendanceStatus.present,
              )
            : AttendanceStatus.present;

        // Parse check-in time
        DateTime? checkedInTime;
        final timestamp = attendanceData['checkedInAt'];
        if (timestamp is Timestamp) {
          checkedInTime = timestamp.toDate();
        }

        // Check if data has actually changed
        if (student.isCheckedInToday != true ||
            student.todayStatus != todayStatus ||
            student.checkedInTime != checkedInTime) {
          hasChanges = true;
          return student.copyWith(
            isCheckedInToday: true,
            todayStatus: todayStatus,
            checkedInTime: checkedInTime,
          );
        }
        return student;
      } else {
        // Not checked in
        if (student.isCheckedInToday) {
          hasChanges = true;
          return EnrolledStudent(
            id: student.id,
            name: student.name,
            email: student.email,
            studentId: student.studentId,
            totalClasses: student.totalClasses,
            attendedClasses: student.attendedClasses,
            isCheckedInToday: false,
            todayStatus: null,
            checkedInTime: null,
          );
        }
        return student;
      }
    }).toList();

    // Only update and notify if there are actual changes
    if (hasChanges) {
      _studentsByClass[classId] = updatedStudents;
      notifyListeners();
    }
  }

  /// Stop listening to attendance updates
  void stopListeningToAttendance() {
    _attendanceListener?.cancel();
    _attendanceListener = null;
  }

  @override
  void dispose() {
    stopListeningToAttendance();
    super.dispose();
  }
}

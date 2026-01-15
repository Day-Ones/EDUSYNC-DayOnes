import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../models/class.dart';
import 'offline_sync_service.dart';
import 'attendance_time_service.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OfflineSyncService _offlineSync = OfflineSyncService();

  // Enable offline persistence
  Future<void> enableOfflinePersistence() async {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Check connectivity
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi);
  }

  // ==================== QR SESSION MANAGEMENT ====================

  /// Faculty creates a QR session (can work offline - will sync later)
  Future<String?> createAttendanceSession({
    required String classId,
    required String className,
    required String facultyId,
    required String facultyName,
  }) async {
    final sessionId = '${classId}_${DateTime.now().millisecondsSinceEpoch}';
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));
    final createdAt = DateTime.now();

    if (await isOnline()) {
      // Online: Save directly to Firebase
      try {
        await _firestore.collection('attendance_sessions').doc(sessionId).set({
          'sessionId': sessionId,
          'classId': classId,
          'className': className,
          'facultyId': facultyId,
          'facultyName': facultyName,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'isActive': true,
        });
      } catch (e) {
        // If online but Firebase fails, save locally
        await _offlineSync.saveQrCodeLocally(
          sessionId: sessionId,
          classId: classId,
          className: className,
          facultyId: facultyId,
          facultyName: facultyName,
          createdAt: createdAt,
          expiresAt: expiresAt,
        );
      }
    } else {
      // Offline: Save locally for later sync
      await _offlineSync.saveQrCodeLocally(
        sessionId: sessionId,
        classId: classId,
        className: className,
        facultyId: facultyId,
        facultyName: facultyName,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );
    }

    return sessionId;
  }

  /// Sync pending QR codes when faculty comes online
  Future<int> syncPendingQrCodes() async {
    if (!await isOnline()) return 0;
    return await _offlineSync.syncPendingQrCodes();
  }

  /// Validate if a session is still active
  Future<Map<String, dynamic>?> validateSession(String sessionId) async {
    try {
      final doc = await _firestore
          .collection('attendance_sessions')
          .doc(sessionId)
          .get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        return null; // Session expired
      }

      return data;
    } catch (e) {
      return null;
    }
  }

  // ==================== ATTENDANCE RECORDING ====================

  /// Record student attendance (works offline - syncs when online)
  Future<Map<String, dynamic>> recordAttendance({
    required String sessionId,
    required String classId,
    required String studentId,
    required String studentName,
    required ClassModel classModel,
  }) async {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final recordId = '${classId}_${studentId}_$dateKey';

    // Validate check-in window
    if (!AttendanceTimeService.canCheckIn(classModel, today)) {
      final message =
          AttendanceTimeService.getCheckInWindowMessage(classModel, today);
      return {'success': false, 'message': message};
    }

    // Calculate attendance status based on check-in time
    final status = AttendanceTimeService.calculateStatus(classModel, today);

    // Check if already checked in locally (for offline scenarios)
    final hasLocalCheckin =
        await _offlineSync.hasCheckedInLocallyToday(classId, studentId);
    if (hasLocalCheckin) {
      return {
        'success': false,
        'message': 'Already checked in today (pending sync)'
      };
    }

    try {
      if (await isOnline()) {
        // Online: Try to save directly to Firebase
        final existingDoc = await _firestore
            .collection('attendance_records')
            .doc(recordId)
            .get();

        if (existingDoc.exists) {
          return {'success': false, 'message': 'Already checked in today'};
        }

        await _firestore.collection('attendance_records').doc(recordId).set({
          'recordId': recordId,
          'sessionId': sessionId,
          'classId': classId,
          'studentId': studentId,
          'studentName': studentName,
          'date': dateKey,
          'checkedInAt': FieldValue.serverTimestamp(),
          'status': status.name,
          'syncedAt': FieldValue.serverTimestamp(),
        });

        final statusMessage = status == AttendanceStatus.present
            ? 'Attendance recorded - Present'
            : status == AttendanceStatus.late
                ? 'Attendance recorded - Late'
                : 'Attendance recorded - Absent';

        return {
          'success': true,
          'message': statusMessage,
          'status': status.name
        };
      } else {
        // Offline: Save locally for later sync
        await _offlineSync.saveAttendanceLocally(
          sessionId: sessionId,
          classId: classId,
          studentId: studentId,
          studentName: studentName,
          date: today,
          checkedInAt: today,
          status: status.name,
        );

        final statusMessage = status == AttendanceStatus.present
            ? 'Attendance saved offline - Present (will sync when online)'
            : status == AttendanceStatus.late
                ? 'Attendance saved offline - Late (will sync when online)'
                : 'Attendance saved offline - Absent (will sync when online)';

        return {
          'success': true,
          'message': statusMessage,
          'status': status.name
        };
      }
    } catch (e) {
      // If online but Firebase fails, save locally
      await _offlineSync.saveAttendanceLocally(
        sessionId: sessionId,
        classId: classId,
        studentId: studentId,
        studentName: studentName,
        date: today,
        checkedInAt: today,
      );

      return {
        'success': true,
        'message': 'Attendance saved offline (will sync when online)'
      };
    }
  }

  /// Sync pending attendance when student comes online
  Future<int> syncPendingAttendance() async {
    if (!await isOnline()) return 0;
    return await _offlineSync.syncPendingAttendance();
  }

  /// Get count of pending attendance records
  Future<int> getPendingAttendanceCount() async {
    return await _offlineSync.getPendingAttendanceCount();
  }

  // ==================== ATTENDANCE QUERIES ====================

  /// Get attendance records for a class
  Stream<List<AttendanceRecord>> getClassAttendance(String classId) {
    return _firestore
        .collection('attendance_records')
        .where('classId', isEqualTo: classId)
        .orderBy('checkedInAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return AttendanceRecord(
                id: data['recordId'],
                classId: data['classId'],
                studentId: data['studentId'],
                studentName: data['studentName'] ?? 'Unknown',
                date: DateTime.parse(data['date']),
                checkedInAt: (data['checkedInAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              );
            }).toList());
  }

  /// Get today's attendance for a class
  Future<List<String>> getTodayAttendance(String classId) async {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final snapshot = await _firestore
        .collection('attendance_records')
        .where('classId', isEqualTo: classId)
        .where('date', isEqualTo: dateKey)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['studentId'] as String)
        .toList();
  }

  /// Get attendance stats for a student in a class
  Future<Map<String, int>> getStudentAttendanceStats(
      String classId, String studentId) async {
    final snapshot = await _firestore
        .collection('attendance_records')
        .where('classId', isEqualTo: classId)
        .where('studentId', isEqualTo: studentId)
        .get();

    return {
      'attended': snapshot.docs.length,
    };
  }

  // ==================== CLASS MANAGEMENT ====================

  /// Save class to Firestore
  Future<void> saveClass(Map<String, dynamic> classData) async {
    await _firestore.collection('classes').doc(classData['id']).set(classData);
  }

  /// Get classes for a user
  Stream<List<Map<String, dynamic>>> getUserClasses(
      String userId, bool isStudent) {
    if (isStudent) {
      return _firestore
          .collection('classes')
          .where('enrolledStudentIds', arrayContains: userId)
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());
    } else {
      return _firestore
          .collection('classes')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());
    }
  }

  /// Enroll student in class
  Future<bool> enrollStudent(
      String classId, String studentId, String studentName) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'enrolledStudentIds': FieldValue.arrayUnion([studentId]),
      });

      // Also save student info
      await _firestore
          .collection('class_students')
          .doc('${classId}_$studentId')
          .set({
        'classId': classId,
        'studentId': studentId,
        'studentName': studentName,
        'enrolledAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Find class by invite code
  Future<Map<String, dynamic>?> findClassByInviteCode(String inviteCode) async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return snapshot.docs.first.data();
    } catch (e) {
      return null;
    }
  }

  /// Unenroll student from class
  Future<bool> unenrollStudent(String classId, String studentId) async {
    try {
      // Remove student from class's enrolledStudentIds array
      await _firestore.collection('classes').doc(classId).update({
        'enrolledStudentIds': FieldValue.arrayRemove([studentId]),
      });

      // Remove student document from class_students collection
      await _firestore
          .collection('class_students')
          .doc('${classId}_$studentId')
          .delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a class and unenroll all students
  Future<bool> deleteClass(String classId) async {
    try {
      // Get all enrolled students for this class
      final studentsSnapshot = await _firestore
          .collection('class_students')
          .where('classId', isEqualTo: classId)
          .get();

      // Delete all class_students documents for this class
      final batch = _firestore.batch();
      for (final doc in studentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the class document
      batch.delete(_firestore.collection('classes').doc(classId));

      // Commit the batch
      await batch.commit();

      return true;
    } catch (e) {
      debugPrint('Error deleting class from Firebase: $e');
      return false;
    }
  }

  /// Get enrolled students for a class
  Future<List<EnrolledStudent>> getEnrolledStudents(String classId) async {
    final snapshot = await _firestore
        .collection('class_students')
        .where('classId', isEqualTo: classId)
        .get();

    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final students = <EnrolledStudent>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final studentId = data['studentId'] as String;

      // Get attendance stats
      final attendanceSnapshot = await _firestore
          .collection('attendance_records')
          .where('classId', isEqualTo: classId)
          .where('studentId', isEqualTo: studentId)
          .get();

      // Check if checked in today and get status
      AttendanceStatus? todayStatus;
      bool todayRecord = false;
      DateTime? checkedInTime;

      for (final attDoc in attendanceSnapshot.docs) {
        final attData = attDoc.data();
        if (attData['date'] == dateKey) {
          todayRecord = true;
          final statusStr = attData['status'] as String?;
          todayStatus = AttendanceStatus.values.firstWhere(
            (e) => e.name == statusStr,
            orElse: () => AttendanceStatus.present,
          );
          // Get the check-in time
          final timestamp = attData['checkedInAt'] as Timestamp?;
          if (timestamp != null) {
            checkedInTime = timestamp.toDate();
          }
          break;
        }
      }

      students.add(EnrolledStudent(
        id: studentId,
        name: data['studentName'] ?? 'Unknown',
        email: data['email'] ?? '',
        studentId: data['studentIdNumber'],
        totalClasses: 10, // You can track this separately
        attendedClasses: attendanceSnapshot.docs.length,
        isCheckedInToday: todayRecord,
        todayStatus: todayStatus,
        checkedInTime: checkedInTime,
      ));
    }

    return students;
  }
}

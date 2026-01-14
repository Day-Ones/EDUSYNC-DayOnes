import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/attendance.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
  
  /// Faculty creates a QR session (must be online)
  Future<String?> createAttendanceSession({
    required String classId,
    required String className,
    required String facultyId,
    required String facultyName,
  }) async {
    if (!await isOnline()) {
      return null; // Faculty must be online
    }

    final sessionId = '${classId}_${DateTime.now().millisecondsSinceEpoch}';
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));

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

    return sessionId;
  }

  /// Validate if a session is still active
  Future<Map<String, dynamic>?> validateSession(String sessionId) async {
    try {
      final doc = await _firestore.collection('attendance_sessions').doc(sessionId).get();
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

  /// Record student attendance (works offline)
  Future<Map<String, dynamic>> recordAttendance({
    required String sessionId,
    required String classId,
    required String studentId,
    required String studentName,
  }) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final recordId = '${classId}_${studentId}_$dateKey';

    try {
      // Check if already checked in today
      final existingDoc = await _firestore
          .collection('attendance_records')
          .doc(recordId)
          .get();

      if (existingDoc.exists) {
        return {'success': false, 'message': 'Already checked in today'};
      }

      // Record attendance
      await _firestore.collection('attendance_records').doc(recordId).set({
        'recordId': recordId,
        'sessionId': sessionId,
        'classId': classId,
        'studentId': studentId,
        'studentName': studentName,
        'date': dateKey,
        'checkedInAt': FieldValue.serverTimestamp(),
        'syncedAt': await isOnline() ? FieldValue.serverTimestamp() : null,
      });

      return {'success': true, 'message': 'Attendance recorded'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
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
            checkedInAt: (data['checkedInAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        }).toList());
  }

  /// Get today's attendance for a class
  Future<List<String>> getTodayAttendance(String classId) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final snapshot = await _firestore
        .collection('attendance_records')
        .where('classId', isEqualTo: classId)
        .where('date', isEqualTo: dateKey)
        .get();

    return snapshot.docs.map((doc) => doc.data()['studentId'] as String).toList();
  }

  /// Get attendance stats for a student in a class
  Future<Map<String, int>> getStudentAttendanceStats(String classId, String studentId) async {
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
  Stream<List<Map<String, dynamic>>> getUserClasses(String userId, bool isStudent) {
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
  Future<bool> enrollStudent(String classId, String studentId, String studentName) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'enrolledStudentIds': FieldValue.arrayUnion([studentId]),
      });

      // Also save student info
      await _firestore.collection('class_students').doc('${classId}_$studentId').set({
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

  /// Get enrolled students for a class
  Future<List<EnrolledStudent>> getEnrolledStudents(String classId) async {
    final snapshot = await _firestore
        .collection('class_students')
        .where('classId', isEqualTo: classId)
        .get();

    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

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

      // Check if checked in today
      final todayRecord = attendanceSnapshot.docs.any((d) => d.data()['date'] == dateKey);

      students.add(EnrolledStudent(
        id: studentId,
        name: data['studentName'] ?? 'Unknown',
        email: data['email'] ?? '',
        studentId: data['studentIdNumber'],
        totalClasses: 10, // You can track this separately
        attendedClasses: attendanceSnapshot.docs.length,
        isCheckedInToday: todayRecord,
      ));
    }

    return students;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../models/class.dart';
import '../models/user.dart';
import 'offline_sync_service.dart';
import 'attendance_time_service.dart';

/// Model for schedule change notifications sent to faculty
class ScheduleChangeNotification {
  ScheduleChangeNotification({
    required this.id,
    required this.classId,
    required this.className,
    required this.officerId,
    required this.officerName,
    required this.changeType,
    required this.changeDescription,
    required this.oldValue,
    required this.newValue,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String classId;
  final String className;
  final String officerId;
  final String officerName;
  final String changeType; // 'time', 'days', 'location', 'room'
  final String changeDescription;
  final String oldValue;
  final String newValue;
  final bool isRead;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'classId': classId,
        'className': className,
        'officerId': officerId,
        'officerName': officerName,
        'changeType': changeType,
        'changeDescription': changeDescription,
        'oldValue': oldValue,
        'newValue': newValue,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ScheduleChangeNotification.fromMap(Map<String, dynamic> map) {
    return ScheduleChangeNotification(
      id: map['id'] as String,
      classId: map['classId'] as String,
      className: map['className'] as String,
      officerId: map['officerId'] as String,
      officerName: map['officerName'] as String,
      changeType: map['changeType'] as String,
      changeDescription: map['changeDescription'] as String,
      oldValue: map['oldValue'] as String,
      newValue: map['newValue'] as String,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
      // Delete the class document first
      await _firestore.collection('classes').doc(classId).delete();

      // Delete class_students documents in smaller batches
      final studentsSnapshot = await _firestore
          .collection('class_students')
          .where('classId', isEqualTo: classId)
          .get();

      for (final doc in studentsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete attendance records
      final attendanceSnapshot = await _firestore
          .collection('attendance_records')
          .where('classId', isEqualTo: classId)
          .get();

      for (final doc in attendanceSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete attendance sessions
      final sessionsSnapshot = await _firestore
          .collection('attendance_sessions')
          .where('classId', isEqualTo: classId)
          .get();

      for (final doc in sessionsSnapshot.docs) {
        await doc.reference.delete();
      }

      debugPrint('Class $classId deleted with all related data');

      return true;
    } catch (e) {
      debugPrint('Error deleting class from Firebase: $e');
      // Save to pending deletes for later sync
      await _offlineSync.saveDeleteLocally(classId);
      debugPrint('Class $classId queued for later deletion');
      return false;
    }
  }

  /// Sync pending class deletes
  Future<int> syncPendingDeletes() async {
    if (!await isOnline()) return 0;
    return await _offlineSync.syncPendingDeletes();
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

  // ==================== OFFICER MANAGEMENT ====================

  /// Add a student as an officer for a class
  Future<bool> addOfficer({
    required String classId,
    required String studentId,
    required String studentName,
  }) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'officerIds': FieldValue.arrayUnion([studentId]),
      });

      // Also save officer info to class_officers collection for easy lookup
      await _firestore
          .collection('class_officers')
          .doc('${classId}_$studentId')
          .set({
        'classId': classId,
        'studentId': studentId,
        'studentName': studentName,
        'assignedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error adding officer: $e');
      return false;
    }
  }

  /// Remove a student from being an officer
  Future<bool> removeOfficer({
    required String classId,
    required String studentId,
  }) async {
    try {
      await _firestore.collection('classes').doc(classId).update({
        'officerIds': FieldValue.arrayRemove([studentId]),
      });

      // Remove officer info from class_officers collection
      await _firestore
          .collection('class_officers')
          .doc('${classId}_$studentId')
          .delete();

      return true;
    } catch (e) {
      debugPrint('Error removing officer: $e');
      return false;
    }
  }

  /// Get all officers for a class
  Future<List<OfficerModel>> getOfficers(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('class_officers')
          .where('classId', isEqualTo: classId)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return OfficerModel(
          studentId: data['studentId'] as String,
          studentName: data['studentName'] as String,
          assignedAt:
              (data['assignedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting officers: $e');
      return [];
    }
  }

  /// Check if a student is an officer for a class
  Future<bool> isOfficer(String classId, String studentId) async {
    try {
      final doc = await _firestore
          .collection('class_officers')
          .doc('${classId}_$studentId')
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // ==================== SCHEDULE CHANGE NOTIFICATIONS ====================

  /// Record a schedule change made by an officer and notify the faculty
  Future<void> recordScheduleChange({
    required String classId,
    required String className,
    required String facultyId,
    required String officerId,
    required String officerName,
    required String changeType,
    required String changeDescription,
    required String oldValue,
    required String newValue,
  }) async {
    try {
      final notificationId =
          '${classId}_${officerId}_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore
          .collection('schedule_change_notifications')
          .doc(notificationId)
          .set({
        'id': notificationId,
        'classId': classId,
        'className': className,
        'facultyId': facultyId,
        'officerId': officerId,
        'officerName': officerName,
        'changeType': changeType,
        'changeDescription': changeDescription,
        'oldValue': oldValue,
        'newValue': newValue,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error recording schedule change: $e');
    }
  }

  /// Get schedule change notifications for a faculty member
  Stream<List<ScheduleChangeNotification>> getScheduleChangeNotifications(
      String facultyId) {
    return _firestore
        .collection('schedule_change_notifications')
        .where('facultyId', isEqualTo: facultyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return ScheduleChangeNotification(
                id: data['id'] as String,
                classId: data['classId'] as String,
                className: data['className'] as String,
                officerId: data['officerId'] as String,
                officerName: data['officerName'] as String,
                changeType: data['changeType'] as String,
                changeDescription: data['changeDescription'] as String,
                oldValue: data['oldValue'] as String,
                newValue: data['newValue'] as String,
                isRead: data['isRead'] as bool? ?? false,
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              );
            }).toList());
  }

  /// Get unread notification count for a faculty member
  Future<int> getUnreadNotificationCount(String facultyId) async {
    try {
      final snapshot = await _firestore
          .collection('schedule_change_notifications')
          .where('facultyId', isEqualTo: facultyId)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Mark a notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('schedule_change_notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for a faculty member
  Future<void> markAllNotificationsAsRead(String facultyId) async {
    try {
      final snapshot = await _firestore
          .collection('schedule_change_notifications')
          .where('facultyId', isEqualTo: facultyId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Update class schedule (can be done by officer)
  Future<bool> updateClassSchedule({
    required String classId,
    required Map<String, dynamic> updates,
    String? officerId,
    String? officerName,
    String? facultyId,
    required String className,
  }) async {
    try {
      // Get old class data for comparison (for notification)
      ClassModel? oldClass;
      if (officerId != null && facultyId != null) {
        final oldDoc =
            await _firestore.collection('classes').doc(classId).get();
        if (oldDoc.exists) {
          oldClass = ClassModel.fromMap(oldDoc.data()!);
        }
      }

      // Update the class
      await _firestore.collection('classes').doc(classId).update(updates);

      // If this is an officer making the change, notify the faculty
      if (officerId != null &&
          officerName != null &&
          facultyId != null &&
          oldClass != null) {
        // Check what changed and create notifications
        if (updates.containsKey('startHour') ||
            updates.containsKey('endHour')) {
          final oldStart =
              '${oldClass.startTime.hour}:${oldClass.startTime.minute.toString().padLeft(2, '0')}';
          final oldEnd =
              '${oldClass.endTime.hour}:${oldClass.endTime.minute.toString().padLeft(2, '0')}';
          final newStart =
              '${updates['startHour'] ?? oldClass.startTime.hour}:${(updates['startMinute'] ?? oldClass.startTime.minute).toString().padLeft(2, '0')}';
          final newEnd =
              '${updates['endHour'] ?? oldClass.endTime.hour}:${(updates['endMinute'] ?? oldClass.endTime.minute).toString().padLeft(2, '0')}';

          await recordScheduleChange(
            classId: classId,
            className: className,
            facultyId: facultyId,
            officerId: officerId,
            officerName: officerName,
            changeType: 'time',
            changeDescription: '$officerName changed the class time',
            oldValue: '$oldStart - $oldEnd',
            newValue: '$newStart - $newEnd',
          );
        }

        if (updates.containsKey('daysOfWeek')) {
          const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final oldDays =
              oldClass.daysOfWeek.map((d) => dayNames[d - 1]).join(', ');
          final newDays = (updates['daysOfWeek'] as List)
              .map((d) => dayNames[(d as int) - 1])
              .join(', ');

          await recordScheduleChange(
            classId: classId,
            className: className,
            facultyId: facultyId,
            officerId: officerId,
            officerName: officerName,
            changeType: 'days',
            changeDescription: '$officerName changed the class days',
            oldValue: oldDays,
            newValue: newDays,
          );
        }

        if (updates.containsKey('location')) {
          await recordScheduleChange(
            classId: classId,
            className: className,
            facultyId: facultyId,
            officerId: officerId,
            officerName: officerName,
            changeType: 'location',
            changeDescription: '$officerName changed the class location',
            oldValue: oldClass.location,
            newValue: updates['location'] as String,
          );
        }

        if (updates.containsKey('instructorOrRoom')) {
          await recordScheduleChange(
            classId: classId,
            className: className,
            facultyId: facultyId,
            officerId: officerId,
            officerName: officerName,
            changeType: 'room',
            changeDescription: '$officerName changed the room',
            oldValue: oldClass.instructorOrRoom,
            newValue: updates['instructorOrRoom'] as String,
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error updating class schedule: $e');
      return false;
    }
  }
}

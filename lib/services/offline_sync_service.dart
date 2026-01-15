import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';

/// Service to handle offline data storage and synchronization
class OfflineSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _keyPendingAttendance = 'pending_attendance';
  static const _keyPendingQrCodes = 'pending_qr_codes';

  // ==================== QR CODE OFFLINE STORAGE ====================

  /// Save QR code locally (for faculty when offline)
  Future<void> saveQrCodeLocally({
    required String sessionId,
    required String classId,
    required String className,
    required String facultyId,
    required String facultyName,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _loadPendingQrCodes();

    existing[sessionId] = {
      'sessionId': sessionId,
      'classId': classId,
      'className': className,
      'facultyId': facultyId,
      'facultyName': facultyName,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isActive': true,
    };

    await prefs.setString(_keyPendingQrCodes, jsonEncode(existing));
    debugPrint('QR code saved locally: $sessionId');
  }

  /// Sync pending QR codes to Firebase (when faculty comes online)
  Future<int> syncPendingQrCodes() async {
    final pending = await _loadPendingQrCodes();
    if (pending.isEmpty) return 0;

    int syncedCount = 0;
    final batch = _firestore.batch();

    for (final entry in pending.entries) {
      final sessionId = entry.key;
      final data = entry.value;

      // Check if not expired
      final expiresAt = DateTime.parse(data['expiresAt']);
      if (DateTime.now().isBefore(expiresAt)) {
        final docRef =
            _firestore.collection('attendance_sessions').doc(sessionId);
        batch.set(docRef, {
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'syncedAt': FieldValue.serverTimestamp(),
        });
        syncedCount++;
      }
    }

    try {
      await batch.commit();
      await _clearPendingQrCodes();
      debugPrint('Synced $syncedCount QR codes to Firebase');
      return syncedCount;
    } catch (e) {
      debugPrint('Error syncing QR codes: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> _loadPendingQrCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPendingQrCodes);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<void> _clearPendingQrCodes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingQrCodes);
  }

  // ==================== ATTENDANCE OFFLINE STORAGE ====================

  /// Save attendance record locally (for students when offline)
  Future<void> saveAttendanceLocally({
    required String sessionId,
    required String classId,
    required String studentId,
    required String studentName,
    required DateTime date,
    required DateTime checkedInAt,
    String status = 'present',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _loadPendingAttendance();

    final recordId =
        '${classId}_${studentId}_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    existing[recordId] = {
      'recordId': recordId,
      'sessionId': sessionId,
      'classId': classId,
      'studentId': studentId,
      'studentName': studentName,
      'date': date.toIso8601String(),
      'checkedInAt': checkedInAt.toIso8601String(),
      'status': status,
    };

    await prefs.setString(_keyPendingAttendance, jsonEncode(existing));
    debugPrint('Attendance saved locally: $recordId (status: $status)');
  }

  /// Sync pending attendance records to Firebase (when student comes online)
  Future<int> syncPendingAttendance() async {
    final pending = await _loadPendingAttendance();
    if (pending.isEmpty) return 0;

    int syncedCount = 0;
    final batch = _firestore.batch();

    for (final entry in pending.entries) {
      final recordId = entry.key;
      final data = entry.value;

      // Check if record already exists in Firebase
      final existingDoc =
          await _firestore.collection('attendance_records').doc(recordId).get();

      if (!existingDoc.exists) {
        final docRef =
            _firestore.collection('attendance_records').doc(recordId);
        final dateStr = data['date'].split('T')[0]; // Extract date part

        batch.set(docRef, {
          'recordId': recordId,
          'sessionId': data['sessionId'],
          'classId': data['classId'],
          'studentId': data['studentId'],
          'studentName': data['studentName'],
          'date': dateStr,
          'checkedInAt': FieldValue.serverTimestamp(),
          'status': data['status'] ?? 'present',
          'syncedAt': FieldValue.serverTimestamp(),
        });
        syncedCount++;
      }
    }

    try {
      await batch.commit();
      await _clearPendingAttendance();
      debugPrint('Synced $syncedCount attendance records to Firebase');
      return syncedCount;
    } catch (e) {
      debugPrint('Error syncing attendance: $e');
      return 0;
    }
  }

  /// Get count of pending records waiting to sync
  Future<int> getPendingAttendanceCount() async {
    final pending = await _loadPendingAttendance();
    return pending.length;
  }

  Future<Map<String, dynamic>> _loadPendingAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPendingAttendance);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<void> _clearPendingAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingAttendance);
  }

  /// Check if student has already checked in locally (offline check)
  Future<bool> hasCheckedInLocallyToday(
      String classId, String studentId) async {
    final pending = await _loadPendingAttendance();
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final recordId = '${classId}_${studentId}_$dateStr';

    return pending.containsKey(recordId);
  }

  /// Clear all offline data
  Future<void> clearAllOfflineData() async {
    await _clearPendingQrCodes();
    await _clearPendingAttendance();
    debugPrint('Cleared all offline data');
  }
}

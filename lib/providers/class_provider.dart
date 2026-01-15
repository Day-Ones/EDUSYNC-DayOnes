import 'package:flutter/material.dart';
import 'package:smart_scheduler/models/class.dart';
import 'package:smart_scheduler/services/local_db_service.dart';
import 'package:smart_scheduler/services/firebase_service.dart';

class ClassProvider extends ChangeNotifier {
  ClassProvider(this._dbService, this._firebaseService);

  final LocalDbService _dbService;
  final FirebaseService _firebaseService;
  List<ClassModel> _classes = [];
  List<ClassModel> _enrolledClasses = [];
  bool _loading = false;
  String? _currentUserId;

  List<ClassModel> get classes => _classes;
  List<ClassModel> get enrolledClasses => _enrolledClasses;
  List<ClassModel> get allClasses => [..._classes, ..._enrolledClasses];
  bool get isLoading => _loading;

  Future<void> loadForUser(String userId, {required bool isStudent}) async {
    _loading = true;
    _currentUserId = userId;
    notifyListeners();

    // Load from local storage first for immediate UI update
    _classes = await _dbService.loadClasses(userId);

    // For students, also load enrolled classes
    if (isStudent) {
      _enrolledClasses = await _dbService.loadEnrolledClasses(userId);
    } else {
      _enrolledClasses = [];
    }

    _loading = false;
    notifyListeners();

    // Then sync with Firebase in the background
    try {
      final isOnline = await _firebaseService.isOnline();
      if (isOnline) {
        final firebaseStream =
            _firebaseService.getUserClasses(userId, isStudent);
        firebaseStream.listen((firebaseClasses) async {
          // Convert Firebase data to ClassModel and update local storage
          for (final classData in firebaseClasses) {
            final classModel = ClassModel.fromMap(classData);
            // Update local storage with Firebase data
            if (isStudent) {
              final localIdx =
                  _enrolledClasses.indexWhere((c) => c.id == classModel.id);
              if (localIdx >= 0) {
                _enrolledClasses[localIdx] = classModel;
              } else {
                _enrolledClasses.add(classModel);
              }
            } else {
              final localIdx =
                  _classes.indexWhere((c) => c.id == classModel.id);
              if (localIdx >= 0) {
                _classes[localIdx] = classModel;
              } else {
                _classes.add(classModel);
              }
            }
            await _dbService.updateClass(classModel);
          }
          notifyListeners();
        });
      }
    } catch (e) {
      // Offline or Firebase error - continue with local data
    }
  }

  Future<void> addOrUpdate(ClassModel model) async {
    final isUpdate = _classes.indexWhere((c) => c.id == model.id) >= 0;

    if (isUpdate) {
      _classes[_classes.indexWhere((c) => c.id == model.id)] = model;
      await _dbService.updateClass(model);
    } else {
      _classes.add(model);
      await _dbService.insertClass(model);
    }
    notifyListeners();

    // Save to Firebase
    try {
      final isOnline = await _firebaseService.isOnline();
      if (isOnline) {
        await _firebaseService.saveClass(model.toMap());
      }
    } catch (e) {
      // Failed to save to Firebase - data is still saved locally
    }
  }

  Future<void> delete(String id) async {
    // Check if class exists in either list
    final classIndex = _classes.indexWhere((c) => c.id == id);
    final enrolledIndex = _enrolledClasses.indexWhere((c) => c.id == id);

    if (classIndex < 0 && enrolledIndex < 0) {
      debugPrint('Class $id not found in any list');
      return; // Class not found
    }

    // Remove from local lists first for immediate UI update
    _classes.removeWhere((c) => c.id == id);
    _enrolledClasses.removeWhere((c) => c.id == id);

    notifyListeners();

    // Delete from local database
    try {
      await _dbService.deleteClass(id);
      debugPrint('Class $id deleted from local DB');
    } catch (e) {
      debugPrint('Error deleting class from local DB: $e');
    }

    // Try to delete from Firebase (will queue for later if fails)
    try {
      final isOnline = await _firebaseService.isOnline();
      if (isOnline) {
        final success = await _firebaseService.deleteClass(id);
        if (success) {
          debugPrint('Firebase delete for class $id: success');
        } else {
          debugPrint('Firebase delete for class $id: queued for later sync');
        }
      } else {
        // Offline - queue for later
        debugPrint('Offline - Firebase delete queued for class $id');
        await _firebaseService
            .syncPendingDeletes(); // This will save to pending
      }
    } catch (e) {
      debugPrint('Firebase delete error (non-fatal): $e');
      // Firebase delete failed but local delete succeeded - that's okay
    }
  }

  /// Sync any pending operations (deletes, etc.)
  Future<void> syncPendingOperations() async {
    try {
      final isOnline = await _firebaseService.isOnline();
      if (isOnline) {
        await _firebaseService.syncPendingDeletes();
      }
    } catch (e) {
      debugPrint('Error syncing pending operations: $e');
    }
  }

  // Join class with invite code
  Future<String?> joinClassWithCode(
      String inviteCode, String studentId, String studentName) async {
    // First try to find the class in Firebase
    ClassModel? classModel;

    try {
      final isOnline = await _firebaseService.isOnline();
      if (isOnline) {
        final firebaseClassData =
            await _firebaseService.findClassByInviteCode(inviteCode);
        if (firebaseClassData != null) {
          classModel = ClassModel.fromMap(firebaseClassData);

          // Check if enrollment is open
          if (!classModel.isEnrollmentOpen) {
            return 'This class is no longer accepting new students. Please contact your instructor.';
          }

          // Check if already enrolled
          if (classModel.enrolledStudentIds.contains(studentId)) {
            return 'You are already enrolled in this class.';
          }

          // Enroll in Firebase
          final enrolled = await _firebaseService.enrollStudent(
              classModel.id, studentId, studentName);

          if (!enrolled) {
            return 'Failed to join class. Please try again.';
          }

          // Save/update the class in local storage
          await _dbService.insertClass(classModel);
        }
      }
    } catch (e) {
      // Fall back to local search if Firebase fails
    }

    // Fallback to local search if offline or Firebase fails
    if (classModel == null) {
      classModel = await _dbService.findClassByInviteCode(inviteCode);
      if (classModel == null) {
        return 'Invalid invite code. Please check and try again.';
      }

      // Check if enrollment is open
      if (!classModel.isEnrollmentOpen) {
        return 'This class is no longer accepting new students. Please contact your instructor.';
      }

      if (classModel.enrolledStudentIds.contains(studentId)) {
        return 'You are already enrolled in this class.';
      }
    }

    // Enroll student in local storage
    final success =
        await _dbService.enrollStudentInClass(classModel.id, studentId);

    if (!success) {
      return 'Failed to join class. Please try again.';
    }

    // Reload enrolled classes from local storage
    _enrolledClasses = await _dbService.loadEnrolledClasses(studentId);
    notifyListeners();

    return null; // Success
  }

  // Leave enrolled class
  Future<void> leaveClass(String classId) async {
    if (_currentUserId == null) return;

    // Update both local storage and Firebase
    await _dbService.unenrollStudentFromClass(classId, _currentUserId!);
    await _firebaseService.unenrollStudent(classId, _currentUserId!);

    _enrolledClasses.removeWhere((c) => c.id == classId);
    notifyListeners();
  }

  // Get class by ID
  ClassModel? getClassById(String id) {
    try {
      return allClasses.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Regenerate invite code for a class
  Future<void> regenerateInviteCode(String classId) async {
    final idx = _classes.indexWhere((c) => c.id == classId);
    if (idx >= 0) {
      final newCode = ClassModel.generateInviteCode();
      final updated = _classes[idx].copyWith(inviteCode: newCode);
      _classes[idx] = updated;
      await _dbService.updateClass(updated);
      notifyListeners();
    }
  }
}

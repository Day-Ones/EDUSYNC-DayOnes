import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/user.dart';

class AuthService {
  AuthService(this._storage);
  final FlutterSecureStorage _storage;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static const _keySession = 'auth_session';
  static const _keyUserType = 'auth_user_type';

  /// Check if device is online
  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet);
    } catch (e) {
      return false;
    }
  }

  /// Login with email and password
  Future<UserModel?> login(String email, String password,
      {required UserType role, bool remember = false}) async {
    // Check internet connection first
    if (!await _isOnline()) {
      throw Exception('Internet connection required to login');
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return null;

      // Get user data from Firestore
      final userDoc =
          await _firestore.collection('users').doc(credential.user!.uid).get();

      if (!userDoc.exists) {
        // User exists in Auth but not in Firestore - sign out
        await _auth.signOut();
        return null;
      }

      final userData = userDoc.data()!;
      final userType = userData['userType'] == 'faculty'
          ? UserType.faculty
          : UserType.student;

      // Check if role matches
      if (userType != role) {
        await _auth.signOut();
        return null;
      }

      final user = _userFromFirestore(credential.user!.uid, userData);

      // Save session locally
      await _storage.write(key: _keySession, value: credential.user!.uid);
      await _storage.write(key: _keyUserType, value: role.name);

      return user;
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.message}');
      return null;
    }
  }

  /// Sign up with email and password
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserType userType,
    String? studentId,
    String? facultyId,
    String? department,
  }) async {
    // Check internet connection first
    if (!await _isOnline()) {
      throw Exception('Internet connection required to sign up');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return null;

      // Create user document in Firestore
      final userData = {
        'id': credential.user!.uid,
        'email': email,
        'fullName': fullName,
        'userType': userType.name,
        'studentId': studentId,
        'facultyId': facultyId,
        'department': department,
        'isGoogleCalendarConnected': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(userData);

      final user = UserModel(
        id: credential.user!.uid,
        email: email,
        fullName: fullName,
        userType: userType,
        studentId: studentId,
        facultyId: facultyId,
        department: department,
        isGoogleCalendarConnected: false,
      );

      // Save session locally
      await _storage.write(key: _keySession, value: credential.user!.uid);
      await _storage.write(key: _keyUserType, value: userType.name);

      return user;
    } on FirebaseAuthException catch (e) {
      print('Signup error: ${e.message}');
      return null;
    }
  }

  /// Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle(
      {required UserType role}) async {
    // Check internet connection first
    if (!await _isOnline()) {
      return {
        'success': false,
        'message': 'Internet connection required to login'
      };
    }

    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return {'success': false, 'message': 'Google sign-in cancelled'};
      }

      // Get auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        return {'success': false, 'message': 'Failed to sign in with Google'};
      }

      // Check if user exists in Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        // Existing user - check role
        final userData = userDoc.data()!;
        final existingRole = userData['userType'] == 'faculty'
            ? UserType.faculty
            : UserType.student;

        if (existingRole != role) {
          await _auth.signOut();
          await _googleSignIn.signOut();
          return {
            'success': false,
            'message':
                'This Google account is registered as ${existingRole.name}. Please select the correct role.',
          };
        }

        final user = _userFromFirestore(userCredential.user!.uid, userData);

        await _storage.write(key: _keySession, value: userCredential.user!.uid);
        await _storage.write(key: _keyUserType, value: role.name);

        return {'success': true, 'user': user, 'isNewUser': false};
      } else {
        // New user - create profile
        final userData = {
          'id': userCredential.user!.uid,
          'email': userCredential.user!.email,
          'fullName': userCredential.user!.displayName ?? 'User',
          'userType': role.name,
          'googleAccountEmail': userCredential.user!.email,
          'isGoogleCalendarConnected': true,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userData);

        final user = UserModel(
          id: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          fullName: userCredential.user!.displayName ?? 'User',
          userType: role,
          googleAccountEmail: userCredential.user!.email,
          isGoogleCalendarConnected: true,
        );

        await _storage.write(key: _keySession, value: userCredential.user!.uid);
        await _storage.write(key: _keyUserType, value: role.name);

        return {'success': true, 'user': user, 'isNewUser': true};
      }
    } catch (e) {
      print('Google sign-in error: $e');
      return {'success': false, 'message': 'Google sign-in failed: $e'};
    }
  }

  /// Restore session from local storage
  Future<UserModel?> restoreSession() async {
    try {
      // Check Firebase Auth state first
      final firebaseUser = _auth.currentUser;

      if (firebaseUser != null) {
        final userDoc =
            await _firestore.collection('users').doc(firebaseUser.uid).get();
        if (userDoc.exists) {
          return _userFromFirestore(firebaseUser.uid, userDoc.data()!);
        }
      }

      // Fallback to local session
      final sessionId = await _storage.read(key: _keySession);
      if (sessionId == null) return null;

      final userDoc = await _firestore.collection('users').doc(sessionId).get();
      if (!userDoc.exists) return null;

      return _userFromFirestore(sessionId, userDoc.data()!);
    } catch (e) {
      print('Restore session error: $e');
      return null;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _storage.delete(key: _keySession);
    await _storage.delete(key: _keyUserType);
  }

  /// Convert Firestore data to UserModel
  UserModel _userFromFirestore(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      userType:
          data['userType'] == 'faculty' ? UserType.faculty : UserType.student,
      studentId: data['studentId'],
      facultyId: data['facultyId'],
      department: data['department'],
      googleAccountEmail: data['googleAccountEmail'],
      isGoogleCalendarConnected: data['isGoogleCalendarConnected'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

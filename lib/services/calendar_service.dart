import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/class.dart';
import '../models/user.dart';

class CalendarService {
  CalendarService(this._googleSignIn);

  final GoogleSignIn _googleSignIn;

  Future<GoogleSignInAccount?> signIn() async {
    return _googleSignIn.signIn();
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }

  Future<String> twoWaySync(UserModel user, List<ClassModel> classes) async {
    await Future.delayed(const Duration(seconds: 1));
    return 'Synced ${classes.length} classes for ${user.fullName}';
  }

  Future<List<ClassModel>> importEvents(UserModel user) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<void> exportEvents(UserModel user, List<ClassModel> classes) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}

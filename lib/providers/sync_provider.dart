import 'package:flutter/material.dart';
import '../models/class.dart';
import '../models/user.dart';
import '../services/calendar_service.dart';

class SyncProvider extends ChangeNotifier {
  SyncProvider(this._calendarService);

  final CalendarService _calendarService;
  DateTime? _lastSync;
  bool _isSyncing = false;
  String? _status;

  DateTime? get lastSync => _lastSync;
  bool get isSyncing => _isSyncing;
  String? get status => _status;

  Future<String?> signIn() async {
    final account = await _calendarService.signIn();
    return account?.email;
  }

  Future<void> signOut() async {
    await _calendarService.signOut();
  }

  Future<void> sync(UserModel user, List<ClassModel> classes) async {
    _isSyncing = true;
    _status = 'Syncing...';
    notifyListeners();
    try {
      final summary = await _calendarService.twoWaySync(user, classes);
      _status = summary;
      _lastSync = DateTime.now();
    } catch (e) {
      _status = 'Sync failed: $e';
    }
    _isSyncing = false;
    notifyListeners();
  }
}

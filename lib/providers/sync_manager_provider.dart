import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';
import '../services/firebase_service.dart';

/// Provider to manage automatic syncing when device comes online
class SyncManagerProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService;
  final FirebaseService _firebaseService;

  SyncManagerProvider(this._connectivityService, this._firebaseService) {
    _connectivityService.addListener(_onConnectivityChanged);
  }

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastSyncStatus;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncStatus => _lastSyncStatus;

  void _onConnectivityChanged() {
    if (_connectivityService.isOnline && !_isSyncing) {
      // Device just came online - trigger sync
      _performAutoSync();
    }
  }

  /// Manually trigger sync
  Future<void> manualSync() async {
    if (!_connectivityService.isOnline) {
      _lastSyncStatus = 'Cannot sync: No internet connection';
      notifyListeners();
      return;
    }

    await _performAutoSync();
  }

  Future<void> _performAutoSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _lastSyncStatus = 'Syncing...';
    notifyListeners();

    try {
      // Sync QR codes (for faculty)
      final qrCount = await _firebaseService.syncPendingQrCodes();

      // Sync attendance records (for students)
      final attendanceCount = await _firebaseService.syncPendingAttendance();

      _lastSyncTime = DateTime.now();

      if (qrCount > 0 || attendanceCount > 0) {
        _lastSyncStatus =
            'Synced: $qrCount QR codes, $attendanceCount attendance records';
        debugPrint(_lastSyncStatus);
      } else {
        _lastSyncStatus = 'All data is up to date';
      }
    } catch (e) {
      _lastSyncStatus = 'Sync failed: $e';
      debugPrint('Auto sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}

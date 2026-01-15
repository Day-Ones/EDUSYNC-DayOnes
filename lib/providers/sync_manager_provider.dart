import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';
import '../services/firebase_service.dart';

/// Provider to manage automatic syncing when device comes online
class SyncManagerProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService;
  final FirebaseService _firebaseService;
  Timer? _periodicSyncTimer;

  SyncManagerProvider(this._connectivityService, this._firebaseService) {
    _connectivityService.addListener(_onConnectivityChanged);
    // Start periodic sync check every 15 seconds
    _startPeriodicSyncCheck();
    // Do initial sync check after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (_connectivityService.isOnline) {
        _performAutoSync();
      }
    });
  }

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastSyncStatus;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncStatus => _lastSyncStatus;

  void _onConnectivityChanged() {
    if (_connectivityService.isOnline && !_isSyncing) {
      // Device just came online - trigger sync immediately
      debugPrint('Connectivity changed to ONLINE - triggering auto sync');
      _performAutoSync();
    }
  }

  /// Start periodic sync check for pending data
  void _startPeriodicSyncCheck() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_connectivityService.isOnline && !_isSyncing) {
        // Check for pending data periodically
        _performAutoSync();
      }
    });
  }

  /// Mark that there's pending data to sync (called after offline operations)
  void markPendingData() {
    // Try to sync immediately if online
    if (_connectivityService.isOnline && !_isSyncing) {
      debugPrint('Pending data marked - attempting immediate sync');
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

      // Sync pending class deletes
      final deleteCount = await _firebaseService.syncPendingDeletes();

      _lastSyncTime = DateTime.now();

      final syncedItems = <String>[];
      if (qrCount > 0) syncedItems.add('$qrCount QR codes');
      if (attendanceCount > 0) syncedItems.add('$attendanceCount attendance records');
      if (deleteCount > 0) syncedItems.add('$deleteCount class deletes');

      if (syncedItems.isNotEmpty) {
        _lastSyncStatus = 'Synced: ${syncedItems.join(', ')}';
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
    _periodicSyncTimer?.cancel();
    _connectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}

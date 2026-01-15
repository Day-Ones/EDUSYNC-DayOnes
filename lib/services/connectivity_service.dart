import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to manage and monitor connectivity status
class ConnectivityService extends ChangeNotifier {
  ConnectivityService() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = false;

  bool get isOnline => _isOnline;

  void _init() {
    // Check initial connectivity
    _checkConnectivity();

    // Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final wasOnline = _isOnline;
      _isOnline = results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);

      // Notify listeners if status changed
      if (wasOnline != _isOnline) {
        debugPrint('Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      _isOnline = false;
      notifyListeners();
    }
  }

  /// Manually check if device is currently online
  Future<bool> checkConnection() async {
    await _checkConnectivity();
    return _isOnline;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

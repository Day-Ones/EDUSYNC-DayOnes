import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/class.dart';

class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  Future<void> scheduleAlerts(ClassModel model) async {
    // For MVP this is a placeholder; extend with timezone-aware scheduling.
  }
}

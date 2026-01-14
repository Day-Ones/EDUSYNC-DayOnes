import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:vibration/vibration.dart';
import '../models/class.dart';

class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  static const int _defaultReminderMinutes = 15;
  
  // Callback for in-app notifications
  static Function(String title, String body, String? classId)? onInAppNotification;
  
  // Timer for checking upcoming classes
  Timer? _classCheckTimer;
  List<ClassModel> _scheduledClasses = [];

  Future<void> init() async {
    // Initialize timezone
    tz_data.initializeTimeZones();
    
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Request notification permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - can navigate to class details
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Schedule alerts for a class
  Future<void> scheduleAlerts(ClassModel model) async {
    if (model.alerts.isEmpty) return;
    
    // Cancel existing notifications for this class
    await cancelAlertsForClass(model.id);
    
    // Schedule new notifications
    for (final alert in model.alerts) {
      if (!alert.isEnabled) continue;
      await _scheduleClassReminder(model, alert.timeBefore);
    }
  }

  /// Schedule a single class reminder
  Future<void> _scheduleClassReminder(ClassModel model, Duration timeBefore) async {
    final now = DateTime.now();
    
    // Find next occurrence of this class
    for (final dayOfWeek in model.daysOfWeek) {
      DateTime classDateTime = _getNextClassDateTime(dayOfWeek, model.startTime);
      DateTime reminderTime = classDateTime.subtract(timeBefore);
      
      // Only schedule if reminder time is in the future
      if (reminderTime.isAfter(now)) {
        final notificationId = '${model.id}_${dayOfWeek}_${timeBefore.inMinutes}'.hashCode;
        
        await _plugin.zonedSchedule(
          notificationId,
          'Class Reminder: ${model.name}',
          'Your class starts in ${_formatDuration(timeBefore)}',
          tz.TZDateTime.from(reminderTime, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'class_reminders',
              'Class Reminders',
              channelDescription: 'Notifications for upcoming classes',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
              color: model.color,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: model.id,
        );
        
        debugPrint('Scheduled notification for ${model.name} at $reminderTime');
        break; // Only schedule for the next occurrence
      }
    }
  }

  DateTime _getNextClassDateTime(int dayOfWeek, TimeOfDay time) {
    final now = DateTime.now();
    int daysUntil = dayOfWeek - now.weekday;
    if (daysUntil < 0) daysUntil += 7;
    if (daysUntil == 0) {
      // Check if class time has passed today
      final classTimeToday = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      if (classTimeToday.isBefore(now)) {
        daysUntil = 7;
      }
    }
    
    final classDate = now.add(Duration(days: daysUntil));
    return DateTime(classDate.year, classDate.month, classDate.day, time.hour, time.minute);
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours >= 24) {
      return '${duration.inHours ~/ 24} day(s)';
    } else if (duration.inHours >= 1) {
      return '${duration.inHours} hour(s)';
    } else {
      return '${duration.inMinutes} minutes';
    }
  }

  /// Cancel all alerts for a specific class
  Future<void> cancelAlertsForClass(String classId) async {
    // Cancel notifications with IDs based on class ID
    for (int day = 1; day <= 7; day++) {
      for (final minutes in [15, 120, 720, 1440]) {
        final notificationId = '${classId}_${day}_$minutes'.hashCode;
        await _plugin.cancel(notificationId);
      }
    }
  }

  /// Show immediate notification (for testing or manual triggers)
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
    Color? color,
  }) async {
    // Vibrate
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    }
    
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminders',
          'Class Reminders',
          channelDescription: 'Notifications for upcoming classes',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          color: color ?? const Color(0xFF2196F3),
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }

  /// Start monitoring classes for in-app notifications
  void startClassMonitoring(List<ClassModel> classes) {
    _scheduledClasses = classes;
    _classCheckTimer?.cancel();
    
    // Check every minute for upcoming classes
    _classCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkUpcomingClasses();
    });
    
    // Also check immediately
    _checkUpcomingClasses();
  }

  void _checkUpcomingClasses() {
    final now = DateTime.now();
    final currentDay = now.weekday;
    final currentMinutes = now.hour * 60 + now.minute;
    
    for (final classModel in _scheduledClasses) {
      if (!classModel.daysOfWeek.contains(currentDay)) continue;
      if (classModel.alerts.isEmpty) continue;
      
      final classStartMinutes = classModel.startTime.hour * 60 + classModel.startTime.minute;
      final minutesUntilClass = classStartMinutes - currentMinutes;
      
      // Check if it's exactly 15 minutes before class
      if (minutesUntilClass == _defaultReminderMinutes) {
        _triggerInAppNotification(classModel);
      }
    }
  }

  Future<void> _triggerInAppNotification(ClassModel classModel) async {
    // Vibrate
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    }
    
    // Trigger in-app callback if set
    if (onInAppNotification != null) {
      onInAppNotification!(
        'Class Starting Soon',
        '${classModel.name} starts in 15 minutes',
        classModel.id,
      );
    }
    
    // Also show push notification
    await showImmediateNotification(
      title: 'Class Starting Soon',
      body: '${classModel.name} starts in 15 minutes',
      payload: classModel.id,
      color: classModel.color,
    );
  }

  /// Stop monitoring
  void stopClassMonitoring() {
    _classCheckTimer?.cancel();
    _classCheckTimer = null;
  }

  /// Update scheduled classes
  void updateScheduledClasses(List<ClassModel> classes) {
    _scheduledClasses = classes;
  }
}

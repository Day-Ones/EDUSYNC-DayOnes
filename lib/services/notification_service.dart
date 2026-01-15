import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/class.dart';
import '../models/reminder_settings.dart';
import '../theme/app_theme.dart';

class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  // Callback for in-app notifications
  static Function(String title, String body, String? classId)?
      onInAppNotification;

  // Timer for checking upcoming classes
  Timer? _classCheckTimer;
  List<ClassModel> _scheduledClasses = [];
  Set<String> _notifiedClasses = {}; // Track which classes we've notified for

  Future<void> init() async {
    // Initialize timezone database and set default to Asia/Manila (Philippines)
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request notification permissions
    await _requestPermissions();

    // Create notification channels
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'class_reminders',
          'Class Reminders',
          description: 'Notifications for upcoming classes',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'faculty_eta',
          'Faculty ETA',
          description: 'Notifications about instructor arrival times',
          importance: Importance.high,
        ),
      );
    }
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Get current reminder settings
  Future<ReminderSettings> _getReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('reminder_settings_v3');
    if (settingsJson != null) {
      return ReminderSettings.fromMap(json.decode(settingsJson));
    }
    return ReminderSettings.defaults();
  }

  /// Schedule alerts for a class based on user's reminder settings
  Future<void> scheduleAlerts(ClassModel model) async {
    // Cancel existing notifications for this class
    await cancelAlertsForClass(model.id);

    // Get user's reminder settings
    final settings = await _getReminderSettings();

    // Schedule class reminders if enabled
    if (settings.classRemindersEnabled) {
      for (final reminder in settings.classReminders) {
        await _scheduleClassReminder(
            model, Duration(minutes: reminder.minutesBefore));
      }
    }

    // Schedule faculty ETA notifications if enabled (fixed times: 60, 30, 15, 5 mins)
    if (settings.facultyEtaEnabled) {
      for (final minutes in ReminderSettings.facultyEtaMinutes) {
        await _scheduleFacultyEtaNotification(
            model, Duration(minutes: minutes));
      }
    }
  }

  /// Schedule a single class reminder
  Future<void> _scheduleClassReminder(
      ClassModel model, Duration timeBefore) async {
    final now = DateTime.now();

    // Find next occurrence of this class
    for (final dayOfWeek in model.daysOfWeek) {
      DateTime classDateTime =
          _getNextClassDateTime(dayOfWeek, model.startTime);
      DateTime reminderTime = classDateTime.subtract(timeBefore);

      // Only schedule if reminder time is in the future
      if (reminderTime.isAfter(now)) {
        final notificationId =
            '${model.id}_class_${dayOfWeek}_${timeBefore.inMinutes}'.hashCode;

        // Generate smart contextual message
        String body = _generateClassReminderMessage(
            model.name, classDateTime, reminderTime);

        await _plugin.zonedSchedule(
          notificationId,
          'Class Reminder',
          body,
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
              styleInformation: BigTextStyleInformation(body),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: model.id,
        );

        debugPrint(
            'Scheduled class reminder for ${model.name} at $reminderTime');
        break; // Only schedule for the next occurrence
      }
    }
  }

  /// Generate smart contextual message for class reminders
  String _generateClassReminderMessage(
      String className, DateTime classDateTime, DateTime reminderTime) {
    final classTimeFormatted =
        _formatTimeOfDay(TimeOfDay.fromDateTime(classDateTime));

    // Check if class is tomorrow (reminder sent today, class is next day)
    final reminderDate =
        DateTime(reminderTime.year, reminderTime.month, reminderTime.day);
    final classDate =
        DateTime(classDateTime.year, classDateTime.month, classDateTime.day);

    if (classDate.isAfter(reminderDate)) {
      // Class is tomorrow or later day
      final daysDiff = classDate.difference(reminderDate).inDays;
      if (daysDiff == 1) {
        return 'You have $className tomorrow';
      } else {
        return 'You have $className in $daysDiff days';
      }
    } else {
      // Class is today (same day as reminder)
      return 'You have $className later at $classTimeFormatted';
    }
  }

  /// Format TimeOfDay to readable string (e.g., "9:30 AM")
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Schedule a faculty ETA notification
  Future<void> _scheduleFacultyEtaNotification(
      ClassModel model, Duration timeBefore) async {
    final now = DateTime.now();

    // Find next occurrence of this class
    for (final dayOfWeek in model.daysOfWeek) {
      DateTime classDateTime =
          _getNextClassDateTime(dayOfWeek, model.startTime);
      DateTime reminderTime = classDateTime.subtract(timeBefore);

      // Only schedule if reminder time is in the future
      if (reminderTime.isAfter(now)) {
        final notificationId =
            '${model.id}_eta_${dayOfWeek}_${timeBefore.inMinutes}'.hashCode;

        // Format: [Faculty name] is [ETA] away at [Campus Name/School Name]
        final facultyName = model.facultyName ?? 'Your instructor';
        final etaText = _formatDuration(timeBefore);
        final location = model.campusLocation?.name ?? model.location;
        String body = '$facultyName is $etaText away at $location';

        await _plugin.zonedSchedule(
          notificationId,
          'Faculty ETA',
          body,
          tz.TZDateTime.from(reminderTime, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'faculty_eta',
              'Faculty ETA',
              channelDescription:
                  'Notifications about instructor arrival times',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
              color: model.color,
              icon: '@mipmap/ic_launcher',
              styleInformation: BigTextStyleInformation(body),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: model.id,
        );

        debugPrint('Scheduled faculty ETA for ${model.name} at $reminderTime');
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
      final classTimeToday =
          DateTime(now.year, now.month, now.day, time.hour, time.minute);
      if (classTimeToday.isBefore(now)) {
        daysUntil = 7;
      }
    }

    final classDate = now.add(Duration(days: daysUntil));
    return DateTime(
        classDate.year, classDate.month, classDate.day, time.hour, time.minute);
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
      // Cancel class reminders
      for (final minutes in [5, 10, 15, 30, 45, 60, 120, 1440]) {
        final notificationId = '${classId}_class_${day}_$minutes'.hashCode;
        await _plugin.cancel(notificationId);
      }
      // Cancel faculty ETA notifications
      for (final minutes in ReminderSettings.facultyEtaMinutes) {
        final notificationId = '${classId}_eta_${day}_$minutes'.hashCode;
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
          color: color ?? AppColors.primary,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }

  /// Start monitoring classes for in-app notifications
  void startClassMonitoring(List<ClassModel> classes) {
    _scheduledClasses = classes;
    _notifiedClasses.clear();
    _classCheckTimer?.cancel();

    // Check every minute for upcoming classes
    _classCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkUpcomingClasses();
    });

    // Also check immediately
    _checkUpcomingClasses();
  }

  Future<void> _checkUpcomingClasses() async {
    final settings = await _getReminderSettings();

    final now = DateTime.now();
    final currentDay = now.weekday;
    final currentMinutes = now.hour * 60 + now.minute;

    for (final classModel in _scheduledClasses) {
      if (!classModel.daysOfWeek.contains(currentDay)) continue;

      final classStartMinutes =
          classModel.startTime.hour * 60 + classModel.startTime.minute;
      final minutesUntilClass = classStartMinutes - currentMinutes;

      // Check class reminders
      if (settings.classRemindersEnabled) {
        for (final reminder in settings.classReminders) {
          final notificationKey =
              '${classModel.id}_class_${reminder.minutesBefore}_$currentDay';

          if (minutesUntilClass == reminder.minutesBefore &&
              !_notifiedClasses.contains(notificationKey)) {
            _notifiedClasses.add(notificationKey);
            await _triggerClassReminderNotification(
                classModel, reminder.minutesBefore);
          }
        }
      }

      // Check faculty ETA notifications
      if (settings.facultyEtaEnabled) {
        for (final minutes in ReminderSettings.facultyEtaMinutes) {
          final notificationKey = '${classModel.id}_eta_${minutes}_$currentDay';

          if (minutesUntilClass == minutes &&
              !_notifiedClasses.contains(notificationKey)) {
            _notifiedClasses.add(notificationKey);
            await _triggerFacultyEtaNotification(classModel, minutes);
          }
        }
      }
    }

    // Clear old notification keys at midnight
    if (now.hour == 0 && now.minute == 0) {
      _notifiedClasses.clear();
    }
  }

  Future<void> _triggerClassReminderNotification(
      ClassModel classModel, int minutesBefore) async {
    // Vibrate
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    }

    final now = DateTime.now();
    final classDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      classModel.startTime.hour,
      classModel.startTime.minute,
    );
    final reminderTime =
        classDateTime.subtract(Duration(minutes: minutesBefore));

    String title = 'Class Reminder';
    String body = _generateClassReminderMessage(
        classModel.name, classDateTime, reminderTime);

    // Trigger in-app callback if set
    if (onInAppNotification != null) {
      onInAppNotification!(title, body, classModel.id);
    }

    // Also show push notification
    await showImmediateNotification(
      title: title,
      body: body,
      payload: classModel.id,
      color: classModel.color,
    );
  }

  Future<void> _triggerFacultyEtaNotification(
      ClassModel classModel, int minutesBefore) async {
    // Vibrate
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    }

    // Format: [Faculty name] is [ETA] away at [Campus Name/School Name]
    final facultyName = classModel.facultyName ?? 'Your instructor';
    final etaText = _formatDuration(Duration(minutes: minutesBefore));
    final location = classModel.campusLocation?.name ?? classModel.location;

    String title = 'Faculty ETA';
    String body = '$facultyName is $etaText away at $location';

    // Trigger in-app callback if set
    if (onInAppNotification != null) {
      onInAppNotification!(title, body, classModel.id);
    }

    // Also show push notification
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'faculty_eta',
          'Faculty ETA',
          channelDescription: 'Notifications about instructor arrival times',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          color: classModel.color,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: classModel.id,
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

import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/material.dart';
import '../models/class.dart';
import '../models/user.dart';

class CalendarService {
  CalendarService(this._googleSignIn);

  final GoogleSignIn _googleSignIn;
  static const String _eventSourceTag = 'EduSync';

  Future<GoogleSignInAccount?> signIn() async {
    // Try silent sign-in first
    final currentUser = _googleSignIn.currentUser;
    if (currentUser != null) {
      return currentUser;
    }
    
    // Try silent sign-in
    final silentUser = await _googleSignIn.signInSilently();
    if (silentUser != null) {
      return silentUser;
    }
    
    // Fall back to interactive sign-in
    return _googleSignIn.signIn();
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }

  /// Sync all classes for the next 7 days (non-recurring events)
  Future<void> syncAllClassesFor7Days(List<ClassModel> classes) async {
    try {
      final account = _googleSignIn.currentUser;
      if (account == null) {
        throw Exception('Not signed in to Google');
      }

      // Get authenticated HTTP client
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        throw Exception('Failed to get authenticated client');
      }

      final calendarApi = calendar.CalendarApi(httpClient);

      // First, clear all existing EduSync events
      await clearAllEvents();

      // Create events for next 7 days
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      for (final classModel in classes) {
        // For each day in the next 7 days
        for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
          final targetDate = today.add(Duration(days: dayOffset));
          final targetWeekday = targetDate.weekday;

          // Check if class occurs on this day
          if (classModel.daysOfWeek.contains(targetWeekday)) {
            final event = _createSingleDayEvent(classModel, targetDate);
            
            try {
              await calendarApi.events.insert(event, 'primary');
            } catch (e) {
              debugPrint('Error inserting event for ${classModel.name} on $targetDate: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing to Google Calendar: $e');
      rethrow;
    }
  }

  /// Clear all EduSync events from Google Calendar
  Future<void> clearAllEvents() async {
    try {
      final account = _googleSignIn.currentUser;
      if (account == null) return;

      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return;

      final calendarApi = calendar.CalendarApi(httpClient);

      // Search for all events with our source tag
      final now = DateTime.now();
      final events = await calendarApi.events.list(
        'primary',
        timeMin: now.subtract(const Duration(days: 30)).toUtc(),
        timeMax: now.add(const Duration(days: 30)).toUtc(),
        maxResults: 2500,
      );

      if (events.items != null) {
        for (final event in events.items!) {
          // Check if this is an EduSync event by checking description
          if (event.id != null && 
              event.description != null &&
              event.description!.contains('Synced from EduSync')) {
            try {
              await calendarApi.events.delete('primary', event.id!);
            } catch (e) {
              debugPrint('Error deleting event ${event.id}: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error clearing Google Calendar events: $e');
    }
  }

  /// Delete calendar events for a specific class
  Future<void> deleteClassEvents(ClassModel classModel) async {
    try {
      final account = _googleSignIn.currentUser;
      if (account == null) return;

      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return;

      final calendarApi = calendar.CalendarApi(httpClient);

      // Search for events matching this class name
      final now = DateTime.now();
      final events = await calendarApi.events.list(
        'primary',
        timeMin: now.subtract(const Duration(days: 7)).toUtc(),
        timeMax: now.add(const Duration(days: 30)).toUtc(),
        maxResults: 500,
        q: classModel.name, // Search by class name
      );

      if (events.items != null) {
        for (final event in events.items!) {
          // Check if this is an EduSync event for this specific class
          if (event.id != null &&
              event.summary == classModel.name &&
              event.description != null &&
              event.description!.contains('Synced from EduSync')) {
            try {
              await calendarApi.events.delete('primary', event.id!);
            } catch (e) {
              debugPrint('Error deleting event ${event.id}: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting class events from Google Calendar: $e');
    }
  }

  /// Create a single-day (non-recurring) event for a specific date
  calendar.Event _createSingleDayEvent(ClassModel classModel, DateTime date) {
    final startDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      classModel.startTime.hour,
      classModel.startTime.minute,
    );
    final endDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      classModel.endTime.hour,
      classModel.endTime.minute,
    );

    // Build location string
    String? location;
    if (classModel.campusLocation != null) {
      location = classModel.campusLocation!.name;
      if (classModel.campusLocation!.room != null) {
        location += ', Room ${classModel.campusLocation!.room}';
      }
    } else if (classModel.location.isNotEmpty) {
      location = classModel.location;
    }

    // Build description
    final description = StringBuffer();
    if (classModel.instructorOrRoom.isNotEmpty) {
      description.writeln('Instructor/Room: ${classModel.instructorOrRoom}');
    }
    if (classModel.location.isNotEmpty) {
      description.writeln('Location: ${classModel.location}');
    }
    description.writeln('\nSynced from EduSync');

    return calendar.Event(
      summary: classModel.name,
      description: description.toString().trim(),
      location: location,
      start: calendar.EventDateTime(
        dateTime: startDateTime,
        timeZone: 'Asia/Manila',
      ),
      end: calendar.EventDateTime(
        dateTime: endDateTime,
        timeZone: 'Asia/Manila',
      ),
      // NO recurrence - single event only
      colorId: _getColorId(classModel.color),
      reminders: calendar.EventReminders(
        useDefault: false,
        overrides: classModel.alerts.where((a) => a.isEnabled).map((alert) {
          return calendar.EventReminder(
            method: 'popup',
            minutes: alert.timeBefore.inMinutes,
          );
        }).toList(),
      ),
    );
  }

  /// Get Google Calendar color ID based on Flutter color
  String _getColorId(Color color) {
    // Google Calendar has 11 color options (1-11)
    // Map Flutter colors to closest Google Calendar colors
    final hue = HSVColor.fromColor(color).hue;
    
    if (hue < 30) return '11'; // Red
    if (hue < 60) return '5';  // Orange
    if (hue < 90) return '10'; // Yellow
    if (hue < 150) return '2'; // Green
    if (hue < 210) return '9'; // Blue
    if (hue < 270) return '1'; // Lavender
    if (hue < 330) return '3'; // Purple
    return '11'; // Default to red
  }

  // Legacy methods - kept for compatibility but not used
  @deprecated
  Future<void> syncClassToCalendar(ClassModel classModel) async {
    // No longer used - use syncAllClassesFor7Days instead
  }

  @deprecated
  Future<void> deleteClassFromCalendar(ClassModel classModel) async {
    // No longer used - use clearAllEvents instead
  }

  @deprecated
  Future<void> updateClassInCalendar(ClassModel classModel) async {
    // No longer used - use syncAllClassesFor7Days instead
  }

  @deprecated
  Future<String> twoWaySync(UserModel user, List<ClassModel> classes) async {
    // No longer used
    return 'Deprecated';
  }

  @deprecated
  Future<List<ClassModel>> importEvents(UserModel user) async {
    // No longer used
    return [];
  }

  @deprecated
  Future<void> exportEvents(UserModel user, List<ClassModel> classes) async {
    // No longer used
  }
}

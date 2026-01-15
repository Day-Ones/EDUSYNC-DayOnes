# Google Calendar Redesign - Changes Completed

## ✅ Completed Changes

### 1. ClassModel (lib/models/class.dart)
- ✅ Removed `syncWithGoogle` field from constructor
- ✅ Removed from class properties
- ✅ Removed from `copyWith()` method
- ✅ Removed from `toMap()` method
- ✅ Removed from `fromMap()` method

### 2. Add/Edit Class Screen (lib/screens/add_edit_class_screen.dart)
- ✅ Removed `bool _syncToGoogle` state variable
- ✅ Removed `bool _includeAlerts` state variable
- ✅ Removed "Add to Google Calendar" SwitchListTile
- ✅ Removed "Include alerts in Google Calendar" CheckboxListTile
- ✅ Removed `syncWithGoogle: _syncToGoogle` from ClassModel constructor

### 3. ClassProvider (lib/providers/class_provider.dart)
- ✅ Removed CalendarService dependency
- ✅ Removed calendar sync logic from `addOrUpdate()` method
- ✅ Removed calendar sync logic from `delete()` method

### 4. Main.dart (lib/main.dart)
- ✅ Removed CalendarService parameter from ClassProvider initialization

### 5. CalendarService (lib/services/calendar_service.dart)
- ✅ Added `syncAllClassesFor7Days(List<ClassModel> classes)` method
- ✅ Added `clearAllEvents()` method
- ✅ Created `_createSingleDayEvent()` for non-recurring events
- ✅ Removed recurring event logic (no more RRULE)
- ✅ Added event tagging with 'EduSync' source for easy identification
- ✅ Deprecated old methods for backward compatibility

## 🔄 Still To Do

### 6. Profile Panel (lib/screens/main_screen.dart)
Need to implement:
- [ ] Functional Google Calendar sync toggle (currently just shows status)
- [ ] Logic to sign in to Google when enabling sync
- [ ] Logic to call `syncAllClassesFor7Days()` when toggle is enabled
- [ ] Logic to call `clearAllEvents()` when toggle is disabled
- [ ] Optional manual "Sync Now" button
- [ ] Update last sync time display

### 7. Daily Background Sync
Need to implement:
- [ ] Add `workmanager` package to pubspec.yaml
- [ ] Create background sync service
- [ ] Schedule daily sync task when toggle is enabled
- [ ] Cancel daily sync task when toggle is disabled
- [ ] Handle app being closed/killed

### 8. UserModel (Optional)
- [ ] Add `DateTime? lastCalendarSyncTime` field if needed

## How It Works Now

### 7-Day Window Logic
- When sync is enabled, creates individual events for next 7 days
- For each class, checks which days in next 7 days match the class schedule
- Creates one event per occurrence (no recurring events)
- Events are tagged with 'EduSync' source for easy identification

### Example
- Today: January 15, 2026 (Wednesday)
- Class: Mon/Wed/Fri, 9:00 AM - 10:00 AM
- Events created:
  - Wed Jan 15, 9:00-10:00 (today)
  - Fri Jan 17, 9:00-10:00
  - Mon Jan 20, 9:00-10:00
  - Wed Jan 22, 9:00-10:00

### Daily Sync (To Be Implemented)
- Background task runs daily (e.g., at midnight)
- Clears old events (before today)
- Creates new events for next 7 days
- Maintains rolling 7-day window automatically

## Testing Checklist

- [x] Can create class without Google Calendar toggle
- [x] Can edit class without Google Calendar toggle
- [ ] Profile toggle enables/disables Google Calendar sync
- [ ] When enabled, all classes appear in Google Calendar for next 7 days
- [ ] When disabled, all events are removed from Google Calendar
- [ ] Manual sync button works (if implemented)
- [ ] Events are created for correct dates/times
- [ ] No recurring events are created
- [ ] Daily background sync maintains 7-day window


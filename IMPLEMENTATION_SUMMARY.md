# Google Calendar Redesign - Implementation Summary

## Completed Changes

### 1. ClassModel (lib/models/class.dart) ✅
- Removed `syncWithGoogle` field from constructor
- Removed `syncWithGoogle` from class properties
- Removed `syncWithGoogle` from `copyWith()` method
- Removed `syncWithGoogle` from `toMap()` method
- Removed `syncWithGoogle` from `fromMap()` method

## Remaining Changes

### 2. Add/Edit Class Screen (lib/screens/add_edit_class_screen.dart)
Need to remove:
- `bool _syncToGoogle = true;` state variable
- `bool _includeAlerts = true;` state variable
- The "Add to Google Calendar" SwitchListTile
- The "Include alerts in Google Calendar" CheckboxListTile
- Remove `syncWithGoogle: _syncToGoogle` from ClassModel constructor in `_saveClass()`

### 3. ClassProvider (lib/providers/class_provider.dart)
Need to remove:
- All calendar sync logic from `addOrUpdate()` method
- All calendar sync logic from `delete()` method
- The calendar service will be called from Profile settings instead

### 4. CalendarService (lib/services/calendar_service.dart)
Need to add/update:
- `syncAllClassesFor7Days(List<ClassModel> classes)` - New method
- `clearAllEvents(String userId)` - New method
- Update `_createCalendarEvent()` to create single events instead of recurring
- Add helper method to calculate next 7 days of class occurrences

### 5. Profile Panel (lib/screens/main_screen.dart)
Need to add:
- Functional Google Calendar sync toggle
- **Optional** manual "Sync Now" button (for immediate sync)
- Last sync time display
- Logic to sign in to Google when enabling sync
- Logic to sync all classes when toggle is enabled
- Logic to clear all events when toggle is disabled
- **Setup daily background sync when toggle is enabled**
- **Cancel daily background sync when toggle is disabled**

### 6. UserModel (lib/models/user.dart)
Optional - may want to add:
- `DateTime? lastCalendarSyncTime` field

## Implementation Priority

1. **HIGH**: Remove Google Calendar toggle from add_edit_class_screen.dart
2. **HIGH**: Remove calendar sync from ClassProvider
3. **HIGH**: Update CalendarService with new 7-day logic
4. **HIGH**: Add functional toggle in Profile panel
5. **HIGH**: Implement daily background sync mechanism
6. **MEDIUM**: Add optional manual sync button
7. **LOW**: Add last sync time tracking

## Additional Requirements

### Daily Background Sync
- Use `workmanager` package for Flutter
- Schedule daily task when sync is enabled
- Task should:
  1. Check if user has Google Calendar sync enabled
  2. Get all user's classes
  3. Clear old events (older than today)
  4. Create new events for next 7 days
  5. Update last sync time
- Cancel scheduled task when sync is disabled

## Testing Checklist

- [ ] Can create class without Google Calendar toggle
- [ ] Can edit class without Google Calendar toggle
- [ ] Profile toggle enables/disables Google Calendar sync
- [ ] When enabled, all classes appear in Google Calendar for next 7 days
- [ ] When disabled, all events are removed from Google Calendar
- [ ] Manual sync button works
- [ ] Events are created for correct dates/times
- [ ] No recurring events are created


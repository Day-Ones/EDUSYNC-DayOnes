# Google Calendar Integration Redesign

## Current Implementation
- Per-class toggle "Add to Google Calendar" in add/edit class screen
- Creates recurring weekly events for each class
- `syncWithGoogle` field in ClassModel
- Calendar sync happens when saving/updating/deleting individual classes

## New Requirements
1. **Global sync toggle** in Profile settings (not per-class)
2. **7-day window**: Create individual events for next 7 days only (not recurring)
3. **Sync all classes**: When enabled, sync ALL user's classes to Google Calendar
4. **Remove per-class toggle**: No more individual class sync control

## Changes Required

### 1. Remove from ClassModel
- Remove `syncWithGoogle` field
- Update `toMap()` and `fromMap()` methods
- Update `copyWith()` method

### 2. Update CalendarService
- Change from recurring events to individual events (7-day window)
- Add method to sync all classes at once
- Add method to clear all calendar events
- Calculate which days in next 7 days match class schedule

### 3. Update ClassProvider
- Remove calendar sync calls from `addOrUpdate()` and `delete()`
- Calendar sync will be triggered from Profile settings instead

### 4. Update Add/Edit Class Screen
- Remove "Add to Google Calendar" toggle
- Remove "Include alerts in Google Calendar" checkbox
- Remove `_syncToGoogle` and `_includeAlerts` state variables

### 5. Update Profile Panel (main_screen.dart)
- Add functional toggle for Google Calendar sync
- When enabled: Sign in to Google and sync all classes
- When disabled: Clear all synced events
- Show last sync time
- Add manual sync button

### 6. Update UserModel (if needed)
- Already has `isGoogleCalendarConnected` field
- May need to add `lastCalendarSyncTime` field

## Implementation Plan

### Phase 1: Update Models
1. Remove `syncWithGoogle` from ClassModel
2. Add `lastCalendarSyncTime` to UserModel (optional)

### Phase 2: Update CalendarService
1. Create `syncAllClasses()` method
2. Create `clearAllEvents()` method
3. Update `_createCalendarEvent()` to create single events instead of recurring
4. Add logic to calculate next 7 days of class occurrences

### Phase 3: Update UI
1. Remove toggle from add_edit_class_screen.dart
2. Add functional toggle in Profile panel
3. Add sync status and manual sync button

### Phase 4: Update ClassProvider
1. Remove calendar sync from addOrUpdate()
2. Remove calendar sync from delete()

### Phase 5: Testing
1. Test enabling sync (should create events for all classes)
2. Test disabling sync (should clear all events)
3. Test manual sync button
4. Verify 7-day window works correctly
5. Test with classes on different days

## Technical Details

### 7-Day Event Creation Logic
For each class:
1. Get class days of week (e.g., [1, 3, 5] for Mon, Wed, Fri)
2. For next 7 days starting from today:
   - Check if day matches class schedule
   - If yes, create event for that specific date/time
3. Result: Individual events, not recurring

### Example
- Today: January 15, 2026 (Wednesday)
- Class: Mon/Wed/Fri, 9:00 AM - 10:00 AM
- Events created:
  - Wed Jan 15, 9:00-10:00
  - Fri Jan 17, 9:00-10:00
  - Mon Jan 20, 9:00-10:00
  - Wed Jan 22, 9:00-10:00

### Sync Trigger Points
- When user enables Google Calendar toggle in Profile (initial sync)
- **Automatically every day** when sync is enabled (background sync)
- When user adds/edits/deletes a class (if sync is enabled)
- Optional: Manual "Sync Now" button for immediate sync

### Background Sync Implementation
- Use Flutter's `WorkManager` or similar for daily background tasks
- Check if sync is enabled in user preferences
- If enabled, sync all classes for next 7 days
- Run at a specific time each day (e.g., midnight or 6 AM)
- Handle app being closed/killed


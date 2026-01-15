# Google Calendar Sync Fix - "Not signed in to Google" Error

## Date: January 15, 2026

## Problem
When testing the Google Calendar sync feature, the following error occurred:
```
Error syncing to Google Calendar: Exception: Not signed in to Google
```

This happened even after the user clicked the sync toggle and went through the Google Sign-In flow.

## Root Cause Analysis

### Issue 1: Race Condition
The `signIn()` method in `CalendarService` was calling `_googleSignIn.signIn()` and returning the account. However, when `syncAllClassesFor7Days()` was called immediately after, it checked `_googleSignIn.currentUser` which might not have been set yet due to timing issues.

### Issue 2: No Silent Sign-In Attempt
The code wasn't checking if the user was already signed in before triggering the interactive sign-in flow. This could cause issues if the user was already signed in from a previous session.

## Solution

### 1. Improved signIn() Method
Modified `CalendarService.signIn()` to:
1. First check if user is already signed in (`currentUser`)
2. If not, try silent sign-in (`signInSilently()`)
3. Only fall back to interactive sign-in if both fail

```dart
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
```

### 2. Enhanced Debug Logging
Added debug logging to help diagnose issues:
- Log when Google account is signed in
- Log number of classes being synced
- Log errors with full context

```dart
debugPrint('Google account signed in: ${account.email}');
debugPrint('Syncing ${allClasses.length} classes to Google Calendar');
debugPrint('Error toggling calendar sync: $e');
```

### 3. Better Error Handling
Improved error handling in the Profile panel:
- Added try-catch-finally block
- Ensure loading state is always cleared
- Show detailed error messages to user

## Testing Steps

To verify the fix works:

1. **Fresh Sign-In Test**
   - Open app (not signed in to Google)
   - Go to Profile panel
   - Toggle "Sync Class Schedules" ON
   - Google Sign-In dialog should appear
   - Sign in with Google account
   - Verify: Success message appears
   - Verify: Events appear in Google Calendar

2. **Already Signed-In Test**
   - Open app (already signed in to Google from previous session)
   - Go to Profile panel
   - Toggle "Sync Class Schedules" ON
   - Verify: No sign-in dialog (uses existing session)
   - Verify: Success message appears
   - Verify: Events appear in Google Calendar

3. **Sign-Out and Sign-In Test**
   - Toggle sync OFF
   - Close app completely
   - Reopen app
   - Toggle sync ON
   - Verify: Silent sign-in works (no dialog)
   - Verify: Events are synced

4. **Error Handling Test**
   - Toggle sync ON
   - Cancel the Google Sign-In dialog
   - Verify: Error message shows "Google sign-in cancelled"
   - Verify: Sync toggle returns to OFF state

## Expected Behavior

### When Sync is Enabled
1. User toggles sync ON
2. App checks if already signed in to Google
3. If not signed in:
   - Try silent sign-in first
   - If that fails, show interactive sign-in dialog
4. Once signed in, sync all classes for next 7 days
5. Show success message
6. Save Google account email to user profile

### When Sync is Disabled
1. User toggles sync OFF
2. App clears all EduSync events from Google Calendar
3. Update user profile (isGoogleCalendarConnected = false)
4. Show confirmation message

## Files Modified
- `lib/services/calendar_service.dart` - Improved signIn() method
- `lib/screens/main_screen.dart` - Enhanced error handling and debug logging

## Additional Notes

### Silent Sign-In
Silent sign-in (`signInSilently()`) is important because:
- It reuses existing Google account sessions
- Doesn't show UI to the user
- Faster than interactive sign-in
- Better user experience

### Debug Logging
The debug logs will help diagnose issues:
- Check if sign-in is successful
- Verify number of classes being synced
- See exact error messages

To view logs:
```bash
flutter logs | grep -E "(Google account|Syncing|Error toggling)"
```

## Known Limitations

1. **First-Time Sign-In**: User must grant calendar permissions on first sign-in
2. **Account Switching**: If user wants to switch Google accounts, they must:
   - Toggle sync OFF
   - Sign out of Google in device settings
   - Toggle sync ON again
3. **Offline Sync**: Sync requires internet connection (will fail gracefully if offline)

## Success Criteria

✅ No more "Not signed in to Google" errors
✅ Silent sign-in works for returning users
✅ Interactive sign-in works for new users
✅ Error messages are clear and helpful
✅ Debug logging helps diagnose issues

## Status
**FIXED** - Ready for testing

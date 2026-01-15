# Firebase-Centric Online/Offline Architecture - Implementation Guide

## Overview
The EduSync app now implements a comprehensive Firebase-centric architecture where all data flows through Firebase. The app requires internet connectivity for authentication but supports offline functionality for attendance recording with automatic synchronization when connectivity is restored.

## Key Features Implemented

### 1. **Internet Required for Login**
- Users cannot login if they are offline
- Both email/password and Google Sign-In require active internet connection
- Clear error messages displayed when attempting to login without internet

### 2. **QR Code Generation (Faculty)**
- Faculty can generate QR codes for attendance even when offline
- QR codes are saved locally first
- When online, QR codes are immediately synced to Firebase
- When offline, QR codes are stored locally and synced automatically when connection is restored

### 3. **Attendance Recording (Students)**
- **Online Mode**: Attendance is recorded instantly to Firebase and appears immediately in the faculty app
- **Offline Mode**: 
  - Attendance is saved locally on the student's device
  - Will NOT appear in faculty app until synced
  - When student comes online, data automatically syncs to Firebase
  - Faculty will then see the attendance record

### 4. **Map Features**
- Map search requires internet connection
- Clear error message shown when trying to search offline
- Prevents API calls when device is offline

### 5. **Automatic Sync**
- Background sync service monitors connectivity
- When device comes online, automatically syncs:
  - Pending QR codes (faculty)
  - Pending attendance records (students)
- Manual sync option available in UI

## New Services Created

### 1. ConnectivityService (`lib/services/connectivity_service.dart`)
```dart
// Monitors device connectivity status
final connectivity = context.watch<ConnectivityService>();
bool isOnline = connectivity.isOnline;
```

### 2. OfflineSyncService (`lib/services/offline_sync_service.dart`)
Handles:
- Local storage of QR codes
- Local storage of attendance records
- Syncing pending data to Firebase
- Checking for duplicate records

### 3. SyncManagerProvider (`lib/providers/sync_manager_provider.dart`)
- Manages automatic syncing when device comes online
- Provides manual sync functionality
- Tracks sync status and last sync time

## UI Components

### ConnectivityBanner Widget
- Shows at top of screens when offline or syncing
- Displays online/offline status
- Shows sync progress
- Provides "Sync Now" button when online

### PendingSyncBadge Widget
- Shows count of pending records waiting to sync
- Displayed as orange badge with sync icon

## Updated Screens

1. **Login Screen** - Requires internet, shows error if offline
2. **Main Screen** - Shows connectivity banner
3. **Student List Screen** - Shows connectivity status, generates QR with online/offline support
4. **Attendance Scanner Screen** - Shows connectivity banner, handles offline attendance
5. **Map Search Screen** - Requires internet for search

## Data Flow Diagrams

### Faculty - QR Code Generation

```
ONLINE:
Faculty → Generate QR → Firebase ← Student scans → Firebase → Faculty sees attendance

OFFLINE (Faculty):
Faculty → Generate QR → Local Storage
          ↓
     (comes online)
          ↓
     Firebase ← Student scans → Firebase → Faculty sees attendance
```

### Student - Attendance Recording

```
ONLINE:
Student → Scan QR → Firebase → Faculty sees immediately

OFFLINE (Student):
Student → Scan QR → Local Storage
          ↓
     (comes online)
          ↓
     Auto sync to Firebase → Faculty sees attendance
```

## Storage Locations

### Local Storage (SharedPreferences)
- `pending_qr_codes` - QR codes waiting to sync (faculty)
- `pending_attendance` - Attendance records waiting to sync (students)

### Firebase Collections
- `attendance_sessions` - Active QR sessions
- `attendance_records` - All attendance records
- `users` - User profiles
- `classes` - Class information

## Testing Scenarios

### Scenario 1: Faculty Offline QR Generation
1. Turn off internet on faculty device
2. Open class student list
3. Tap QR code icon
4. QR code is generated and displayed
5. Turn on internet
6. QR session automatically syncs to Firebase

### Scenario 2: Student Offline Attendance
1. Faculty generates QR code (online)
2. Student turns off internet
3. Student scans QR code
4. Attendance saved locally (message: "saved offline")
5. Faculty does NOT see attendance yet
6. Student turns on internet
7. Attendance auto-syncs to Firebase
8. Faculty now sees the attendance record

### Scenario 3: Login Requires Internet
1. Turn off internet
2. Try to login
3. Error message: "Internet connection required to login"
4. Turn on internet
5. Login succeeds

### Scenario 4: Map Search Offline
1. Turn off internet
2. Navigate to map search
3. Try to search for location
4. Error: "Internet connection required for search"

## Migration Notes

### Breaking Changes
- `AttendanceProvider` now requires `FirebaseService` in constructor
- `generateAttendanceQr()` now requires `facultyId` and `facultyName` parameters
- Map search will fail gracefully when offline instead of crashing

### New Dependencies
All required dependencies already exist in `pubspec.yaml`:
- `connectivity_plus` - Network connectivity monitoring
- `shared_preferences` - Local storage
- `cloud_firestore` - Firebase database

## Best Practices

### For Faculty:
- Generate QR codes before class (online or offline)
- QR codes are valid for 5 minutes
- Check connectivity banner to see if attendance data is syncing

### For Students:
- Scan QR code as soon as possible
- Check connectivity banner to see if attendance has synced
- Attendance shows "pending sync" badge when offline

### For Developers:
- Always check `ConnectivityService.isOnline` before Firebase operations
- Use `OfflineSyncService` for operations that should work offline
- Show appropriate UI feedback for offline operations
- Handle both online and offline cases in error handling

## Monitoring Sync Status

```dart
// In any widget
final syncManager = context.watch<SyncManagerProvider>();

if (syncManager.isSyncing) {
  // Show loading indicator
}

if (syncManager.lastSyncStatus != null) {
  // Show sync status message
}
```

## Manual Sync

```dart
// Trigger manual sync
final syncManager = context.read<SyncManagerProvider>();
await syncManager.manualSync();
```

## Troubleshooting

### Attendance not showing for faculty
- Check if student is online (connectivity banner)
- Check pending sync count
- Wait for auto-sync or trigger manual sync

### QR code not working
- Ensure QR code is not expired (>5 minutes old)
- Check if faculty device was online when QR was generated
- Refresh QR code if needed

### Cannot login
- Check internet connection
- Verify Firebase is accessible
- Check credentials

## Future Enhancements

1. Conflict resolution for duplicate attendance records
2. Batch sync optimization for large datasets
3. Retry mechanism for failed syncs
4. Offline mode indicator in app bar
5. Detailed sync logs for debugging
6. Push notifications when sync completes

# Smart Scheduler (Frontend-Only MVP)

Flutter mobile app for students and faculty to manage class schedules with Google Calendar integration, local storage, and multi-alert reminders. This MVP is frontend-only: all logic runs on-device.

## Features
- Email/password auth (local secure storage) with Student/Faculty roles
- Dashboards tailored per role (stats, quick actions, recent items)
- Weekly & daily views, add/edit classes with color palette and multi-alert toggles
- Google Calendar stub flows (sign-in, sync/import/export placeholders, conflict screen)
- Search & filter, profile/settings, logout
- Local-first storage using SharedPreferences + secure storage stubs, ready to swap to sqflite
- Sample test accounts: student@test.com / password123, faculty@test.com / password123

## Project Structure (key files)
- [lib/main.dart](lib/main.dart): App entry, routing, providers
- [lib/theme/app_theme.dart](lib/theme/app_theme.dart): Colors, typography, theming
- [lib/models/user.dart](lib/models/user.dart): User, Class, Alert models
- [lib/providers](lib/providers): Auth/Class/Sync providers
- [lib/services](lib/services): Auth/local DB/Calendar/Notification stubs
- [lib/screens](lib/screens): UI screens (auth, dashboards, schedule views, add class, settings, search)
- [lib/widgets](lib/widgets): Reusable cards and list tiles

## Getting Started
1) Prereqs: Flutter 3.16+ (Dart 3), Android SDK 21+/iOS 12+.
2) Install packages:
```bash
flutter pub get
```
3) Run (Android/iOS):
```bash
flutter run
```

## Google Calendar Setup (client-side only)
- Add an OAuth client in Google Cloud Console with Calendar API enabled.
- For Android: add reversed client ID in android/app/src/main/AndroidManifest.xml if you later wire native config.
- For iOS: add REVERSED_CLIENT_ID to ios/Runner/Info.plist and URL scheme; update GoogleService-Info.plist as needed.
- Update scopes in [lib/main.dart](lib/main.dart) if you change permissions.
- The current build uses google_sign_in + googleapis; Calendar calls are stubbed—fill in CalendarService to call events endpoints and wire tokens.

## Local Auth & Storage
- Credentials stored with flutter_secure_storage; sessions kept in secure storage.
- Remember-me uses shared_preferences.
- Passwords are demo-hashed (base64) for MVP; replace with bcrypt/crypto for production.

## Testing Accounts
- Student: student@test.com / password123
- Faculty: faculty@test.com / password123

## Next Steps
- Implement real Calendar import/export and conflict resolution in CalendarService
- Replace SharedPreferences store with sqflite schema (users, classes, alerts tables)
- Add notification scheduling via flutter_local_notifications + timezone
- Add accessibility audits and more detailed validation states
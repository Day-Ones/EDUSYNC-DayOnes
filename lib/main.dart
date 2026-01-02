import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'models/user.dart';
import 'providers/auth_provider.dart';
import 'providers/class_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/add_edit_class_screen.dart';
import 'screens/calendar_settings_screen.dart';
import 'screens/conflict_resolution_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/daily_view_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_filter_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/weekly_view_screen.dart';
import 'services/auth_service.dart';
import 'services/calendar_service.dart';
import 'services/local_db_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final googleSignIn = GoogleSignIn(scopes: [
    'email',
    'https://www.googleapis.com/auth/calendar',
  ]);
  final authService = AuthService(const FlutterSecureStorage());
  final dbService = LocalDbService();
  final calendarService = CalendarService(googleSignIn);

  runApp(SmartSchedulerApp(
    authService: authService,
    dbService: dbService,
    calendarService: calendarService,
  ));
}

class SmartSchedulerApp extends StatelessWidget {
  const SmartSchedulerApp({super.key, required this.authService, required this.dbService, required this.calendarService});

  final AuthService authService;
  final LocalDbService dbService;
  final CalendarService calendarService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)..bootstrap()),
        ChangeNotifierProvider(create: (_) => ClassProvider(dbService)),
        ChangeNotifierProvider(create: (_) => SyncProvider(calendarService)),
      ],
      child: MaterialApp(
        title: 'Smart Scheduler',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const SplashScreen(),
        routes: {
          RoleSelectionScreen.routeName: (_) => const RoleSelectionScreen(),
          LoginScreen.routeName: (_) => const LoginScreen(),
          SignUpScreen.routeName: (_) => const SignUpScreen(),
          DashboardScreen.routeName: (_) => const DashboardScreen(),
          WeeklyViewScreen.routeName: (_) => const WeeklyViewScreen(),
          DailyViewScreen.routeName: (_) => const DailyViewScreen(),
          AddEditClassScreen.routeName: (_) => const AddEditClassScreen(),
          CalendarSettingsScreen.routeName: (_) => const CalendarSettingsScreen(),
          ProfileScreen.routeName: (_) => const ProfileScreen(),
          SearchFilterScreen.routeName: (_) => const SearchFilterScreen(),
          ConflictResolutionScreen.routeName: (_) => const ConflictResolutionScreen(),
        },
      ),
    );
  }
}

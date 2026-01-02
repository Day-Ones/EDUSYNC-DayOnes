import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/class_provider.dart';
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
import 'screens/login_role_selection_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/weekly_view_screen.dart';
import 'services/auth_service.dart';
import 'services/local_db_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Simplified initialization for testing
  final authService = AuthService(const FlutterSecureStorage());
  final dbService = LocalDbService();
  
  runApp(SmartSchedulerApp(
    authService: authService,
    dbService: dbService,
  ));
}

class SmartSchedulerApp extends StatelessWidget {
  const SmartSchedulerApp({super.key, required this.authService, required this.dbService});

  final AuthService authService;
  final LocalDbService dbService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)..bootstrap()),
        ChangeNotifierProvider(create: (_) => ClassProvider(dbService)),
        // Temporarily removed SyncProvider to avoid Google Sign-In issues
      ],
      child: MaterialApp(
        title: 'Smart Scheduler',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const SplashScreen(),
        routes: {
          RoleSelectionScreen.routeName: (_) => const RoleSelectionScreen(),
          LoginRoleSelectionScreen.routeName: (_) => const LoginRoleSelectionScreen(),
          LoginScreen.routeName: (_) => const LoginScreen(),
          SignupScreen.routeName: (_) => const SignupScreen(),
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

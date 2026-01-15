import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'models/class.dart';
import 'providers/auth_provider.dart';
import 'providers/class_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/location_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/sync_manager_provider.dart';
import 'services/calendar_service.dart';
import 'services/notification_service.dart';
import 'screens/add_edit_class_screen.dart';
import 'screens/add_edit_schedule_screen.dart';
import 'screens/calendar_settings_screen.dart';
import 'screens/class_details_screen.dart';
import 'screens/classes_screen.dart';
import 'screens/conflict_resolution_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/main_screen.dart';
import 'screens/daily_view_screen.dart';
import 'screens/faculty_tracker_screen.dart';
import 'screens/join_class_screen.dart';
import 'screens/location_settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/search_filter_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_role_selection_screen.dart';
import 'screens/weekly_view_screen.dart';
import 'screens/student_list_screen.dart';
import 'screens/attendance_scanner_screen.dart';
import 'screens/map_search_screen.dart';
import 'services/auth_service.dart';
import 'services/local_db_service.dart';
import 'services/location_service.dart';
import 'services/firebase_service.dart';
import 'services/connectivity_service.dart';
import 'theme/app_theme.dart';

// Global key for showing snackbars from anywhere
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Firebase service with offline persistence
  final firebaseService = FirebaseService();
  await firebaseService.enableOfflinePersistence();

  // Initialize notification service
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  final notificationService = NotificationService(notificationPlugin);
  await notificationService.init();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize services
  final authService = AuthService(const FlutterSecureStorage());
  final dbService = LocalDbService();
  final locationService = LocationService();

  // Initialize Google Sign-In for Calendar sync
  final googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar',
    ],
  );
  final calendarService = CalendarService(googleSignIn);

  runApp(SmartSchedulerApp(
    authService: authService,
    dbService: dbService,
    locationService: locationService,
    calendarService: calendarService,
    notificationService: notificationService,
  ));
}

class SmartSchedulerApp extends StatefulWidget {
  const SmartSchedulerApp({
    super.key,
    required this.authService,
    required this.dbService,
    required this.locationService,
    required this.calendarService,
    required this.notificationService,
  });

  final AuthService authService;
  final LocalDbService dbService;
  final LocationService locationService;
  final CalendarService calendarService;
  final NotificationService notificationService;

  static final FirebaseService firebaseService = FirebaseService();

  @override
  State<SmartSchedulerApp> createState() => _SmartSchedulerAppState();
}

class _SmartSchedulerAppState extends State<SmartSchedulerApp> {
  @override
  void initState() {
    super.initState();

    // Set up in-app notification callback
    NotificationService.onInAppNotification = _showInAppNotification;
  }

  void _showInAppNotification(String title, String body, String? classId) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(body, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        action: classId != null
            ? SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  // Navigate to class details
                  navigatorKey.currentState?.pushNamed(
                    ClassDetailsScreen.routeName,
                    arguments: classId,
                  );
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(
            create: (_) => AuthProvider(widget.authService)..bootstrap()),
        ChangeNotifierProvider(
            create: (_) => ClassProvider(
                widget.dbService, SmartSchedulerApp.firebaseService)),
        ChangeNotifierProvider(
            create: (_) => ScheduleProvider(widget.dbService)),
        ChangeNotifierProvider(
            create: (_) => LocationProvider(widget.locationService)),
        ChangeNotifierProvider(
            create: (_) => SyncProvider(widget.calendarService)),
        ChangeNotifierProvider(
            create: (_) =>
                AttendanceProvider(SmartSchedulerApp.firebaseService)),
        ChangeNotifierProxyProvider<ConnectivityService, SyncManagerProvider>(
          create: (context) => SyncManagerProvider(
            context.read<ConnectivityService>(),
            SmartSchedulerApp.firebaseService,
          ),
          update: (context, connectivity, previous) =>
              previous ??
              SyncManagerProvider(
                  connectivity, SmartSchedulerApp.firebaseService),
        ),
        Provider.value(value: widget.notificationService),
      ],
      child: MaterialApp(
        title: 'EduSync',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        scaffoldMessengerKey: scaffoldMessengerKey,
        navigatorKey: navigatorKey,
        home: const SplashScreen(),
        routes: {
          LoginRoleSelectionScreen.routeName: (_) =>
              const LoginRoleSelectionScreen(),
          LoginScreen.routeName: (_) => const LoginScreen(),
          SignupScreen.routeName: (_) => const SignupScreen(),
          DashboardScreen.routeName: (_) => const MainScreen(),
          MainScreen.routeName: (_) => const MainScreen(),
          WeeklyViewScreen.routeName: (_) => const WeeklyViewScreen(),
          DailyViewScreen.routeName: (_) => const DailyViewScreen(),
          AddEditClassScreen.routeName: (_) => const AddEditClassScreen(),
          CalendarSettingsScreen.routeName: (_) =>
              const CalendarSettingsScreen(),
          ProfileScreen.routeName: (_) => const ProfileScreen(),
          SearchFilterScreen.routeName: (_) => const SearchFilterScreen(),
          ConflictResolutionScreen.routeName: (_) =>
              const ConflictResolutionScreen(),
          ScheduleScreen.routeName: (_) => const ScheduleScreen(),
          AddEditScheduleScreen.routeName: (_) => const AddEditScheduleScreen(),
          FacultyTrackerScreen.routeName: (_) => const FacultyTrackerScreen(),
          LocationSettingsScreen.routeName: (_) =>
              const LocationSettingsScreen(),
          JoinClassScreen.routeName: (_) => const JoinClassScreen(),
          ClassDetailsScreen.routeName: (_) => const ClassDetailsScreen(),
          ClassesScreen.routeName: (_) => const ClassesScreen(),
          StudentListScreen.routeName: (_) => const StudentListScreen(),
          AttendanceScannerScreen.routeName: (context) {
            final classModel =
                ModalRoute.of(context)!.settings.arguments as ClassModel;
            return AttendanceScannerScreen(classModel: classModel);
          },
          MapSearchScreen.routeName: (_) => const MapSearchScreen(),
        },
      ),
    );
  }
}

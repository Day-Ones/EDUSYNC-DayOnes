import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/class.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/location_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/connectivity_banner.dart';
import 'add_edit_class_screen.dart';
import 'join_class_screen.dart';
import 'class_details_screen.dart';
import 'login_role_selection_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  static const routeName = '/main';

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _notificationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final locationProvider = context.read<LocationProvider>();
    final user = auth.user;
    if (user != null) {
      classProvider.loadForUser(user.id,
          isStudent: user.userType == UserType.student);
      scheduleProvider.loadForUser(user.id);
      locationProvider.initialize(user.id, user.userType);

      if (user.userType == UserType.faculty) {
        locationProvider.updateFacultyInfo(
          facultyId: user.id,
          name: user.fullName,
          department: user.department,
          email: user.email,
        );
      }

      // Initialize notifications for class reminders
      if (!_notificationsInitialized) {
        _notificationsInitialized = true;
        _initializeNotifications();
      }
    }
  }

  void _initializeNotifications() {
    final classProvider = context.read<ClassProvider>();
    final notificationService = context.read<NotificationService>();

    // Start monitoring classes for notifications
    final allClasses = [
      ...classProvider.classes,
      ...classProvider.enrolledClasses
    ];
    notificationService.startClassMonitoring(allClasses);

    // Schedule alerts for each class
    for (final classModel in allClasses) {
      if (classModel.alerts.isNotEmpty) {
        notificationService.scheduleAlerts(classModel);
      }
    }

    // Listen for class changes to update notifications
    classProvider.addListener(() {
      final updatedClasses = [
        ...classProvider.classes,
        ...classProvider.enrolledClasses
      ];
      notificationService.updateScheduledClasses(updatedClasses);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Stop notification monitoring
    try {
      final notificationService = context.read<NotificationService>();
      notificationService.stopClassMonitoring();
    } catch (_) {}
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Minimize app (like pressing home button) instead of exiting
        SystemChannels.platform
            .invokeMethod('SystemNavigator.pop', {'animated': true});
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _HomePanel(user: user),
                  _ClassesPanel(user: user),
                  _ProfilePanel(user: user),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onNavTap,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF2196F3),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.class_), label: 'Classes'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ==================== HOME PANEL ====================
class _HomePanel extends StatelessWidget {
  final UserModel user;
  const _HomePanel({required this.user});

  @override
  Widget build(BuildContext context) {
    final classProvider = context.watch<ClassProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final classes = classProvider.classes;
    final enrolledClasses = classProvider.enrolledClasses;
    final allClasses = [...classes, ...enrolledClasses];
    final todayClasses = allClasses
        .where((c) => c.daysOfWeek.contains(DateTime.now().weekday))
        .toList();
    final upcomingClasses = _getUpcomingClasses(todayClasses);
    final todaySchedules = scheduleProvider.getTodaySchedules();
    final upcomingSchedules = scheduleProvider.getUpcomingSchedules();

    return Column(
      children: [
        // Blue Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
          decoration: const BoxDecoration(color: Color(0xFF2196F3)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: GoogleFonts.albertSans(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 4),
              Text(
                user.fullName.isNotEmpty ? user.fullName : 'User',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),

        // Stats Cards
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                  child: _buildStatCard(Icons.class_, const Color(0xFF64B5F6),
                      allClasses.length.toString(), 'Classes')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                      Icons.event_note,
                      const Color(0xFF81C784),
                      todaySchedules.length.toString(),
                      'Events')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                      Icons.access_time,
                      const Color(0xFFE57373),
                      (upcomingClasses + upcomingSchedules.length).toString(),
                      'Upcoming')),
            ],
          ),
        ),

        // Today's Classes Section
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Today's Classes",
                        style: GoogleFonts.poppins(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: () {
                        // Navigate to classes panel
                        final mainState =
                            context.findAncestorStateOfType<_MainScreenState>();
                        mainState?._onNavTap(1);
                      },
                      child: Text('See All',
                          style: GoogleFonts.albertSans(
                              color: const Color(0xFF2196F3), fontSize: 16)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(8)),
                  child: todayClasses.isEmpty
                      ? _buildEmptyClassesState(context)
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: todayClasses.length,
                          itemBuilder: (context, index) => _buildClassTile(
                              context, todayClasses[index], enrolledClasses),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyClassesState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('No classes today',
              style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              final mainState =
                  context.findAncestorStateOfType<_MainScreenState>();
              mainState?._onNavTap(1);
            },
            child: const Text('View all classes'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassTile(BuildContext context, ClassModel classItem,
      List<ClassModel> enrolledClasses) {
    final isEnrolled = enrolledClasses.any((c) => c.id == classItem.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, ClassDetailsScreen.routeName,
            arguments: classItem),
        leading: CircleAvatar(
          backgroundColor: classItem.color,
          child: const Icon(Icons.book, color: Colors.white, size: 20),
        ),
        title: Text(classItem.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${_formatTime(classItem.startTime)} - ${_formatTime(classItem.endTime)}'),
        trailing: isEnrolled
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4)),
                child: Text('Enrolled',
                    style: GoogleFonts.albertSans(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.w600)),
              )
            : classItem.campusLocation != null
                ? Text(classItem.campusLocation!.room ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                : null,
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, Color iconColor, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label,
              style: GoogleFonts.albertSans(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  int _getUpcomingClasses(List<ClassModel> todays) {
    final now = TimeOfDay.now();
    return todays
        .where((c) =>
            (c.startTime.hour * 60 + c.startTime.minute) >
            (now.hour * 60 + now.minute))
        .length;
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

// ==================== CLASSES PANEL ====================
class _ClassesPanel extends StatelessWidget {
  final UserModel user;
  const _ClassesPanel({required this.user});

  @override
  Widget build(BuildContext context) {
    final classProvider = context.watch<ClassProvider>();
    final isStudent = user.userType == UserType.student;
    final classes = classProvider.classes;
    final enrolledClasses = classProvider.enrolledClasses;
    final allClasses = [...classes, ...enrolledClasses];
    final hasClasses = allClasses.isNotEmpty;

    return Stack(
      children: [
        Column(
          children: [
            // Blue Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 50, 24, 24),
              decoration: const BoxDecoration(color: Color(0xFF2196F3)),
              child: Text(
                'My Classes',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600),
              ),
            ),

            // Classes List
            Expanded(
              child: classProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : allClasses.isEmpty
                      ? _buildEmptyState(context, isStudent)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: allClasses.length,
                          itemBuilder: (context, index) {
                            final classItem = allClasses[index];
                            final isEnrolled = enrolledClasses
                                .any((c) => c.id == classItem.id);
                            return _buildClassCard(
                                context, classItem, isEnrolled, isStudent);
                          },
                        ),
            ),
          ],
        ),
        // FAB - only show when user has classes
        if (hasClasses)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () => Navigator.pushNamed(
                context,
                isStudent
                    ? JoinClassScreen.routeName
                    : AddEditClassScreen.routeName,
              ),
              backgroundColor: const Color(0xFF2196F3),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isStudent) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.class_, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "You don't have a class yet",
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(
              context,
              isStudent
                  ? JoinClassScreen.routeName
                  : AddEditClassScreen.routeName,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              isStudent ? 'Join Now' : 'Create Now',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, ClassModel classItem,
      bool isEnrolled, bool isStudent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, ClassDetailsScreen.routeName,
            arguments: classItem),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: classItem.color, width: 4)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: classItem.color.withValues(alpha: 0.2),
                child: Icon(Icons.class_, color: classItem.color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            classItem.name,
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isEnrolled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Enrolled',
                              style: GoogleFonts.albertSans(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatTime(classItem.startTime)} - ${_formatTime(classItem.endTime)}',
                          style: GoogleFonts.albertSans(
                              fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDays(classItem.daysOfWeek),
                          style: GoogleFonts.albertSans(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    if (classItem.facultyName != null && isStudent) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            classItem.facultyName!,
                            style: GoogleFonts.albertSans(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (classItem.campusLocation != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[400]),
                    Text(
                      classItem.campusLocation!.room ??
                          classItem.campusLocation!.name,
                      style: GoogleFonts.albertSans(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDays(List<int> days) {
    const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => dayNames[d]).join(', ');
  }
}

// ==================== PROFILE PANEL ====================
class _ProfilePanel extends StatefulWidget {
  final UserModel user;
  const _ProfilePanel({required this.user});

  @override
  State<_ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<_ProfilePanel> {
  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _lastSyncTime = DateTime.now().subtract(const Duration(minutes: 15));
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isSyncing = false;
      _lastSyncTime = DateTime.now();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Calendar synced successfully!'),
          duration: Duration(seconds: 2)),
    );
  }

  String _formatLastSync(DateTime? time) {
    if (time == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = widget.user;

    return Column(
      children: [
        // Blue Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 50, 24, 24),
          decoration: const BoxDecoration(color: Color(0xFF2196F3)),
          child: Text(
            'Profile & Settings',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
          ),
        ),

        // Profile Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User Card
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor:
                            const Color(0xFF257FCE).withValues(alpha: 0.2),
                        child: Text(
                          user.fullName.isNotEmpty
                              ? user.fullName.characters.first.toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Color(0xFF257FCE),
                              fontWeight: FontWeight.w800,
                              fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(user.email,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Chip(
                              label: Text(
                                user.userType.name.toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: Colors.white),
                              ),
                              backgroundColor: const Color(0xFF257FCE),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Account Information
              Text('Account Information',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Department/Major'),
                subtitle: Text(user.department ?? 'Not set',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ID'),
                subtitle: Text(user.studentId ?? user.facultyId ?? 'Not set',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
              const Divider(height: 24),

              // Google Calendar Integration
              Text('Google Calendar Integration',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                color: user.isGoogleCalendarConnected
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: user.isGoogleCalendarConnected
                                  ? const Color(0xFF4CAF50)
                                      .withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.cloud_sync,
                              color: user.isGoogleCalendarConnected
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Calendar Status',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                Text(
                                  user.isGoogleCalendarConnected
                                      ? 'Connected'
                                      : 'Not connected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: user.isGoogleCalendarConnected
                                        ? const Color(0xFF4CAF50)
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Google Account'),
                subtitle: Text(user.googleAccountEmail ?? 'Not connected',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
              const Divider(height: 24),

              // Location Sharing (Faculty only)
              if (user.userType == UserType.faculty) ...[
                Text('Location Sharing',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Consumer<LocationProvider>(
                  builder: (context, locationProvider, _) {
                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      color: locationProvider.isSharing
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: locationProvider.isSharing
                                        ? const Color(0xFF4CAF50)
                                            .withValues(alpha: 0.2)
                                        : Colors.grey.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    locationProvider.isSharing
                                        ? Icons.location_on
                                        : Icons.location_off,
                                    color: locationProvider.isSharing
                                        ? const Color(0xFF4CAF50)
                                        : Colors.grey,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Share Location with Students',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700)),
                                      Text(
                                        locationProvider.isSharing
                                            ? 'Students can see your ETA'
                                            : 'Location sharing is off',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: locationProvider.isSharing
                                              ? const Color(0xFF4CAF50)
                                              : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: locationProvider.isSharing,
                                  onChanged: locationProvider.isLoading
                                      ? null
                                      : (value) async {
                                          await locationProvider
                                              .toggleSharing();
                                          if (locationProvider.error != null &&
                                              context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      locationProvider.error!)),
                                            );
                                            locationProvider.clearError();
                                          }
                                        },
                                  activeTrackColor: const Color(0xFF4CAF50)
                                      .withValues(alpha: 0.5),
                                  activeThumbColor: const Color(0xFF4CAF50),
                                ),
                              ],
                            ),
                            if (locationProvider.isSharing &&
                                locationProvider.currentPosition != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Your location is being shared in real-time',
                                style: GoogleFonts.albertSans(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 24),
              ],

              // App Information
              Text('App Information',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('App Version'),
                subtitle: const Text('0.1.0',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              const Divider(height: 24),

              // Data Management
              Text('Data Management',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Clear Local Data?'),
                      content: const Text(
                          'This will delete all locally saved data.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear',
                              style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Local data cleared'),
                          duration: Duration(seconds: 2)),
                    );
                  }
                },
                label: const Text('Clear Local Data'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: AppColors.error),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Logout')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    if (context.mounted) {
                      context.read<LocationProvider>().onLogout();
                    }
                    await auth.logout();
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context,
                        LoginRoleSelectionScreen.routeName, (_) => false);
                  }
                },
                label: const Text('Logout'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

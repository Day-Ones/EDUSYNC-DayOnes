import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/class.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/loading_overlay.dart';
import 'profile_screen.dart';
import 'classes_screen.dart';
import 'class_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  static const routeName = '/dashboard';

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final locationProvider = context.read<LocationProvider>();
    final user = auth.user;
    if (user != null) {
      classProvider.loadForUser(user.id, isStudent: user.userType == UserType.student);
      scheduleProvider.loadForUser(user.id);
      locationProvider.initialize(user.id, user.userType);
      
      // Update faculty info if user is faculty
      if (user.userType == UserType.faculty) {
        locationProvider.updateFacultyInfo(
          facultyId: user.id,
          name: user.fullName,
          department: user.department,
          email: user.email,
        );
      }
    }
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classProvider = context.watch<ClassProvider>();
    final classes = classProvider.classes;
    final enrolledClasses = classProvider.enrolledClasses;
    final scheduleProvider = context.watch<ScheduleProvider>();
    final user = auth.user;

    if (user == null) {
      return const FullScreenLoading(
        message: 'Loading...',
        subMessage: 'Please wait while we set things up',
      );
    }

    final allClasses = [...classes, ...enrolledClasses];
    final todayClasses = allClasses.where((c) => c.daysOfWeek.contains(DateTime.now().weekday)).toList();
    final upcomingClasses = _getUpcomingClasses(todayClasses);
    final todaySchedules = scheduleProvider.getTodaySchedules();
    final upcomingSchedules = scheduleProvider.getUpcomingSchedules();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
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
                  style: GoogleFonts.albertSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 4),
                Text(
                  user.fullName.isNotEmpty ? user.fullName : 'User',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          
          // Stats Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildStatCard(Icons.class_, const Color(0xFF64B5F6), allClasses.length.toString(), 'Classes')),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(Icons.event_note, const Color(0xFF81C784), todaySchedules.length.toString(), 'Events')),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(Icons.access_time, const Color(0xFFE57373), (upcomingClasses + upcomingSchedules.length).toString(), 'Upcoming')),
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
                      Text("Today's Classes", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, ClassesScreen.routeName),
                        child: Text('See All', style: GoogleFonts.albertSans(color: const Color(0xFF2196F3), fontSize: 16)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(8)),
                    child: todayClasses.isEmpty
                        ? _buildEmptyClassesState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: todayClasses.length,
                            itemBuilder: (context, index) => _buildClassTile(todayClasses[index], enrolledClasses),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) Navigator.pushNamed(context, ClassesScreen.routeName);
          if (index == 2) Navigator.pushNamed(context, ProfileScreen.routeName);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2196F3),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.class_), label: 'Classes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildEmptyClassesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('No classes today', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, ClassesScreen.routeName),
            child: const Text('View all classes'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassTile(ClassModel classItem, List<ClassModel> enrolledClasses) {
    final isEnrolled = enrolledClasses.any((c) => c.id == classItem.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, ClassDetailsScreen.routeName, arguments: classItem),
        leading: CircleAvatar(
          backgroundColor: classItem.color,
          child: const Icon(Icons.book, color: Colors.white, size: 20),
        ),
        title: Text(classItem.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${_formatTime(classItem.startTime)} - ${_formatTime(classItem.endTime)}'),
        trailing: isEnrolled
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('Enrolled', style: GoogleFonts.albertSans(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
              )
            : classItem.campusLocation != null
                ? Text(classItem.campusLocation!.room ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                : null,
      ),
    );
  }

  Widget _buildStatCard(IconData icon, Color iconColor, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.albertSans(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  int _getUpcomingClasses(List<ClassModel> todays) {
    final now = TimeOfDay.now();
    return todays.where((c) => (c.startTime.hour * 60 + c.startTime.minute) > (now.hour * 60 + now.minute)).length;
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

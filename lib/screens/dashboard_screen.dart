import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import 'daily_view_screen.dart';
import 'weekly_view_screen.dart';
import 'profile_screen.dart';

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
    final user = auth.user;
    if (user != null) {
      classProvider.loadForUser(user.id, isStudent: user.userType == UserType.student);
    }
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classes = context.watch<ClassProvider>().classes;
    final user = auth.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isStudent = user.userType == UserType.student;
    final todayClasses = classes.where((c) => c.daysOfWeek.contains(DateTime.now().weekday)).toList();
    final upcomingClasses = _getUpcomingClasses(todayClasses);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Blue Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
            decoration: const BoxDecoration(
              color: Color(0xFF2196F3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: GoogleFonts.albertSans(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.fullName.isNotEmpty ? user.fullName : 'User',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
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
                  child: _buildStatCard(
                    icon: Icons.calendar_today,
                    iconColor: const Color(0xFF64B5F6),
                    value: classes.length.toString(),
                    label: 'Total Classes',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.calendar_today,
                    iconColor: const Color(0xFF81C784),
                    value: todayClasses.length.toString(),
                    label: 'Today',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.access_time,
                    iconColor: const Color(0xFFE57373),
                    value: upcomingClasses.toString(),
                    label: 'Upcoming',
                  ),
                ),
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
                      Text(
                        "Today's Classes",
                        style: GoogleFonts.poppins(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, DailyViewScreen.routeName),
                        child: Text(
                          'See All',
                          style: GoogleFonts.albertSans(
                            color: const Color(0xFF2196F3),
                            fontSize: 28,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: todayClasses.isEmpty
                        ? const Center(
                            child: Text(
                              'No classes today',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: todayClasses.length,
                            itemBuilder: (context, index) {
                              final classItem = todayClasses[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: classItem.color,
                                    child: const Icon(Icons.book, color: Colors.white, size: 20),
                                  ),
                                  title: Text(
                                    classItem.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${_formatTime(context, classItem.startTime)} - ${_formatTime(context, classItem.endTime)}',
                                  ),
                                  trailing: Text(
                                    classItem.location,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              );
                            },
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
          switch (index) {
            case 0:
              // Home - already here
              break;
            case 1:
              Navigator.pushNamed(context, WeeklyViewScreen.routeName);
              break;
            case 2:
              Navigator.pushNamed(context, DailyViewScreen.routeName);
              break;
            case 3:
              Navigator.pushNamed(context, ProfileScreen.routeName);
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2196F3),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.albertSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.albertSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Weekly Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_agenda),
            label: 'Daily Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.albertSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  int _getUpcomingClasses(List<ClassModel> todays) {
    final now = TimeOfDay.now();
    return todays.where((c) => _compareTime(c.startTime, now) > 0).length;
  }



  int _compareTime(TimeOfDay a, TimeOfDay b) {
    final aMinutes = a.hour * 60 + a.minute;
    final bMinutes = b.hour * 60 + b.minute;
    return aMinutes.compareTo(bMinutes);
  }

  String _formatTime(BuildContext context, TimeOfDay t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute;
    final period = t.hour >= 12 ? 'PM' : 'AM';
    if (minute == 0) return '$hour $period';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr $period';
  }


}

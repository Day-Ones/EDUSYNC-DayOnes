import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/nav_card.dart';
import '../widgets/stat_card.dart';
import 'add_edit_class_screen.dart';
import 'calendar_settings_screen.dart';
import 'daily_view_screen.dart';
import 'search_filter_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classes = context.watch<ClassProvider>().classes;
    final user = auth.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isStudent = user.userType == UserType.student;

    return Scaffold(
      appBar: AppBar(
        title: Text(isStudent ? 'Welcome back, ${user.fullName.split(' ').first}' : 'Welcome, Prof. ${user.fullName.split(' ').first}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, ProfileScreen.routeName),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AddEditClassScreen.routeName),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatCard(
                title: isStudent ? 'Total Classes This Week' : 'Total Lectures This Week',
                value: classes.length.toString(),
                subtitle: 'Stay on top of your schedule',
                icon: Icons.auto_graph,
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  NavCard(
                    title: isStudent ? 'My Schedule' : 'Teaching Schedule',
                    icon: Icons.calendar_view_week,
                    onTap: () => Navigator.pushNamed(context, WeeklyViewScreen.routeName),
                  ),
                  NavCard(
                    title: isStudent ? "Today's Classes" : "Today's Lectures",
                    icon: Icons.today,
                    onTap: () => Navigator.pushNamed(context, DailyViewScreen.routeName),
                  ),
                  NavCard(
                    title: isStudent ? 'Add Class' : 'Add Lecture',
                    icon: Icons.add_box,
                    onTap: () => Navigator.pushNamed(context, AddEditClassScreen.routeName),
                  ),
                  NavCard(
                    title: 'Google Sync',
                    icon: Icons.cloud_sync,
                    onTap: () => Navigator.pushNamed(context, CalendarSettingsScreen.routeName),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Recent', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...classes.take(3).map((c) => ListTile(
                    leading: CircleAvatar(backgroundColor: c.color, child: const Icon(Icons.book, color: Colors.white)),
                    title: Text(c.name),
                    subtitle: Text('${c.location} • ${c.daysOfWeek.length} days/week'),
                  )),
              if (classes.isEmpty)
                const Text('No classes yet. Tap + to add.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, SearchFilterScreen.routeName),
                icon: const Icon(Icons.search),
                label: const Text('Search & Filter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
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
    final roleColor = isStudent ? const Color(0xFF1E88E5) : const Color(0xFF0D47A1);
    final accentColor = isStudent ? const Color(0xFF1DE9B6) : const Color(0xFF64B5F6);
    final greeting = _greeting();
    final todayClasses = classes.where((c) => c.daysOfWeek.contains(DateTime.now().weekday)).toList();
    final next = _nextClass(todayClasses);
    final totalThisWeek = classes.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: roleColor.withOpacity(0.2),
              child: Text(user.fullName.isNotEmpty ? user.fullName.characters.first.toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Smart Scheduler', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  Text(greeting, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(isStudent ? 'Student' : 'Faculty', style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Profile & Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, ProfileScreen.routeName),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickActions(context, isStudent),
        backgroundColor: roleColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(context),
              const SizedBox(height: 12),
              StatCard(
                title: isStudent ? 'Classes this week' : 'Lectures this week',
                value: totalThisWeek.toString(),
                subtitle: next != null ? 'Next: ${next.name} at ${_formatTime(context, next.startTime)}' : 'No upcoming items today',
                icon: Icons.auto_graph,
                trend: '↑ steady',
                trendColor: accentColor,
                actionLabel: 'View all',
                onAction: () => Navigator.pushNamed(context, WeeklyViewScreen.routeName),
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
                    subtitle: 'Weekly overview',
                    meta: '${classes.length} total',
                    accent: roleColor,
                    onTap: () => Navigator.pushNamed(context, WeeklyViewScreen.routeName),
                  ),
                  NavCard(
                    title: isStudent ? "Today's Classes" : "Today's Lectures",
                    icon: Icons.today,
                    subtitle: '${todayClasses.length} today',
                    meta: next != null ? 'Next ${_formatTime(context, next.startTime)}' : 'Free',
                    accent: accentColor,
                    onTap: () => Navigator.pushNamed(context, DailyViewScreen.routeName),
                  ),
                  NavCard(
                    title: 'Drafts',
                    icon: Icons.edit_note,
                    subtitle: 'Saved to finish',
                    meta: 'Pick up later',
                    accent: roleColor,
                    onTap: () => Navigator.pushNamed(context, AddEditClassScreen.routeName),
                  ),
                  NavCard(
                    title: 'Google Sync',
                    icon: Icons.cloud_sync,
                    subtitle: 'Two-way calendar',
                    meta: 'Last sync: –',
                    accent: accentColor,
                    onTap: () => Navigator.pushNamed(context, CalendarSettingsScreen.routeName),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Recent', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (classes.isEmpty)
                const Text('No classes yet. Tap + to add.', style: TextStyle(color: AppColors.textSecondary)),
              ...classes.take(4).map((c) {
                final status = _statusLabel(c);
                final statusColor = _statusColor(status);
                return Card(
                  child: ListTile(
                    onTap: () => Navigator.pushNamed(context, DailyViewScreen.routeName),
                    leading: CircleAvatar(backgroundColor: c.color, child: const Icon(Icons.book, color: Colors.white)),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${_formatTime(context, c.startTime)} - ${_formatTime(context, c.endTime)} | ${c.location}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                          child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 6),
                        Text('${c.daysOfWeek.length} days/week', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search classes, rooms, professors',
                ),
                onTap: () => Navigator.pushNamed(context, SearchFilterScreen.routeName),
                readOnly: true,
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, SearchFilterScreen.routeName),
              icon: const Icon(Icons.filter_list),
              label: const Text('Filters'),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  ClassModel? _nextClass(List<ClassModel> todays) {
    if (todays.isEmpty) return null;
    final now = TimeOfDay.now();
    todays.sort((a, b) => _compareTime(a.startTime, b.startTime));
    for (final c in todays) {
      if (_compareTime(c.startTime, now) > 0) return c;
    }
    return todays.first;
  }

  int _compareTime(TimeOfDay a, TimeOfDay b) {
    final aMinutes = a.hour * 60 + a.minute;
    final bMinutes = b.hour * 60 + b.minute;
    return aMinutes.compareTo(bMinutes);
  }

  String _formatTime(BuildContext context, TimeOfDay t) {
    final loc = MaterialLocalizations.of(context);
    return loc.formatTimeOfDay(t, alwaysUse24HourFormat: false);
  }

  String _statusLabel(ClassModel c) {
    final now = TimeOfDay.now();
    if (_compareTime(c.startTime, now) > 0) return 'Upcoming';
    if (_compareTime(c.endTime, now) > 0) return 'In progress';
    return 'Done';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'In progress':
        return AppColors.accent;
      case 'Upcoming':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showQuickActions(BuildContext context, bool isStudent) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: Text(isStudent ? 'Add Class' : 'Add Lecture'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AddEditClassScreen.routeName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

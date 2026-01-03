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
        toolbarHeight: 104,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: roleColor.withValues(alpha: 0.2),
                child: Text(user.fullName.isNotEmpty ? user.fullName.characters.first.toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Smart Scheduler', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Text(greeting, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(isStudent ? 'Student' : 'Faculty', style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              const SizedBox(height: 16),
              // Weekly Timeline View
              _buildWeeklyTimeline(context, classes),
              const SizedBox(height: 20),
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
                    icon: Icons.folder_open,
                    subtitle: 'Saved to finish',
                    meta: 'Pick up later',
                    accent: roleColor,
                    onTap: () => Navigator.pushNamed(context, AddEditClassScreen.routeName),
                  ),
                  NavCard(
                    title: 'Google Sync',
                    icon: Icons.cloud_sync,
                    subtitle: 'Two-way calendar',
                    meta: user.isGoogleCalendarConnected ? 'Connected' : 'Not connected',
                    accent: accentColor,
                    onTap: () => Navigator.pushNamed(context, CalendarSettingsScreen.routeName),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Classes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
                  if (classes.isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, WeeklyViewScreen.routeName),
                      child: const Text('See all', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (classes.isEmpty)
                const Text('No classes yet. Tap + to add.', style: TextStyle(color: AppColors.textSecondary)),
              ...classes.take(4).map((c) {
                final status = _statusLabel(c);
                final statusColor = _statusColor(status);
                final hasConflict = _hasConflict(c, classes);
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: hasConflict ? const BorderSide(color: AppColors.error, width: 2) : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasConflict)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.warning_rounded, size: 14, color: AppColors.error),
                                  SizedBox(width: 4),
                                  Text('Conflict detected', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: c.color,
                              child: c.syncWithGoogle
                                  ? const Icon(Icons.cloud_done, color: Colors.white, size: 20)
                                  : const Icon(Icons.book, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatTime(context, c.startTime)} - ${_formatTime(context, c.endTime)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 13, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          c.location,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (c.instructorOrRoom.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      c.instructorOrRoom,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(height: 6),
                                Text('${c.daysOfWeek.length}d/wk', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
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
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onTap: () => Navigator.pushNamed(context, SearchFilterScreen.routeName),
                readOnly: true,
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, SearchFilterScreen.routeName),
              icon: const Icon(Icons.filter_list),
              label: const Text('Filters'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                visualDensity: VisualDensity.compact,
                alignment: Alignment.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTimeline(BuildContext context, List<ClassModel> classes) {
    final days = ['M', 'T', 'W', 'Th', 'F', 'S', 'Su'];
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Week', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (index) {
                  final dayDate = startOfWeek.add(Duration(days: index));
                  final isToday = isSameDay(dayDate, now);
                  final dayClasses = classes.where((c) => c.daysOfWeek.contains(dayDate.weekday)).toList();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, DailyViewScreen.routeName),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isToday ? const Color(0xFF257FCE).withValues(alpha: 0.1) : Colors.transparent,
                          border: Border.all(color: isToday ? const Color(0xFF257FCE) : Colors.grey.shade300, width: isToday ? 2 : 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(days[index], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isToday ? const Color(0xFF257FCE) : Colors.black87)),
                            const SizedBox(height: 4),
                            Text(dayDate.day.toString(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            if (dayClasses.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF257FCE).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('${dayClasses.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF257FCE))),
                              )
                            else
                              const Text('-', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasConflict(ClassModel c, List<ClassModel> allClasses) {
    for (final other in allClasses) {
      if (c.id == other.id) continue;
      if (!c.daysOfWeek.any((day) => other.daysOfWeek.contains(day))) continue;
      
      final cStart = c.startTime.hour * 60 + c.startTime.minute;
      final cEnd = c.endTime.hour * 60 + c.endTime.minute;
      final oStart = other.startTime.hour * 60 + other.startTime.minute;
      final oEnd = other.endTime.hour * 60 + other.endTime.minute;
      
      if (cStart < oEnd && cEnd > oStart) return true;
    }
    return false;
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
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute;
    final period = t.hour >= 12 ? 'PM' : 'AM';
    if (minute == 0) return '$hour $period';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr $period';
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/class.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../theme/app_theme.dart';
import 'class_details_screen.dart';

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});
  static const routeName = '/schedule-management';

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final List<String> _shortDayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize tab controller - start on today's day (weekday is 1-based, so subtract 1)
    final todayIndex = DateTime.now().weekday - 1;
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: todayIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ClassModel> _getClassesForDay(
      List<ClassModel> allClasses, int dayIndex) {
    // dayIndex is 0-based (0=Monday), weekday in model is 1-based (1=Monday)
    final weekday = dayIndex + 1;
    final classes =
        allClasses.where((c) => c.daysOfWeek.contains(weekday)).toList();
    // Sort by start time
    classes.sort((a, b) {
      final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
      final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
      return aMinutes.compareTo(bMinutes);
    });
    return classes;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDuration(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final durationMinutes = endMinutes - startMinutes;
    if (durationMinutes >= 60) {
      final hours = durationMinutes ~/ 60;
      final mins = durationMinutes % 60;
      if (mins > 0) {
        return '${hours}h ${mins}m';
      }
      return '${hours}h';
    }
    return '${durationMinutes}m';
  }

  bool _isCurrentClass(ClassModel classModel) {
    final now = DateTime.now();
    if (!classModel.daysOfWeek.contains(now.weekday)) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes =
        classModel.startTime.hour * 60 + classModel.startTime.minute;
    final endMinutes = classModel.endTime.hour * 60 + classModel.endTime.minute;

    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  bool _isUpcomingClass(ClassModel classModel) {
    final now = DateTime.now();
    if (!classModel.daysOfWeek.contains(now.weekday)) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes =
        classModel.startTime.hour * 60 + classModel.startTime.minute;

    return startMinutes > nowMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classProvider = context.watch<ClassProvider>();
    final user = auth.user;
    final allClasses = [
      ...classProvider.classes,
      ...classProvider.enrolledClasses,
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user, allClasses),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(7, (index) {
                  final classes = _getClassesForDay(allClasses, index);
                  return _buildDaySchedule(context, index, classes);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, UserModel? user, List<ClassModel> allClasses) {
    final totalClasses = allClasses.length;
    final todayClasses =
        _getClassesForDay(allClasses, DateTime.now().weekday - 1);
    final totalHoursToday = _calculateTotalHours(todayClasses);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Schedule',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View and manage your class schedule',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Quick stats row
          Row(
            children: [
              _buildStatChip(
                Icons.school_rounded,
                '$totalClasses Classes',
                AppColors.primary,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.today_rounded,
                '${todayClasses.length} Today',
                AppColors.success,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.schedule_rounded,
                '$totalHoursToday hrs today',
                AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateTotalHours(List<ClassModel> classes) {
    int totalMinutes = 0;
    for (final c in classes) {
      final startMinutes = c.startTime.hour * 60 + c.startTime.minute;
      final endMinutes = c.endTime.hour * 60 + c.endTime.minute;
      totalMinutes += (endMinutes - startMinutes);
    }
    final hours = totalMinutes / 60;
    return hours.toStringAsFixed(1);
  }

  Widget _buildTabBar() {
    final today = DateTime.now().weekday - 1; // 0-based

    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textTertiary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: List.generate(7, (index) {
          final isToday = index == today;
          return Tab(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_shortDayNames[index]),
                  if (isToday) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'Today',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDaySchedule(
      BuildContext context, int dayIndex, List<ClassModel> classes) {
    if (classes.isEmpty) {
      return _buildEmptyDay(dayIndex);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final classModel = classes[index];
        final isFirst = index == 0;
        final isLast = index == classes.length - 1;
        final isCurrent = _isCurrentClass(classModel);
        final isUpcoming = _isUpcomingClass(classModel) &&
            dayIndex == DateTime.now().weekday - 1;

        return _buildClassTimelineItem(
          context,
          classModel,
          isFirst: isFirst,
          isLast: isLast,
          isCurrent: isCurrent,
          isUpcoming: isUpcoming,
        );
      },
    );
  }

  Widget _buildEmptyDay(int dayIndex) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 48,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No classes on ${_dayNames[dayIndex]}',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy your free day!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassTimelineItem(
    BuildContext context,
    ClassModel classModel, {
    required bool isFirst,
    required bool isLast,
    required bool isCurrent,
    required bool isUpcoming,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator
          SizedBox(
            width: 60,
            child: Column(
              children: [
                // Time label
                Text(
                  _formatTime(classModel.startTime).split(' ')[0],
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        isCurrent ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  _formatTime(classModel.startTime).split(' ')[1],
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color:
                        isCurrent ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Timeline line and dot
          Column(
            children: [
              Container(
                width: 2,
                height: 8,
                color: isFirst ? Colors.transparent : AppColors.border,
              ),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primary
                      : (isUpcoming
                          ? AppColors.warning
                          : AppColors.textTertiary),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surface,
                    width: 3,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : AppColors.border,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Class card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child:
                  _buildClassCard(context, classModel, isCurrent, isUpcoming),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(
    BuildContext context,
    ClassModel classModel,
    bool isCurrent,
    bool isUpcoming,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          ClassDetailsScreen.routeName,
          arguments: classModel,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isCurrent
                ? AppColors.primary
                : (isUpcoming ? AppColors.warning : AppColors.border),
            width: isCurrent ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: classModel.color,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classModel.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatTime(classModel.startTime)} - ${_formatTime(classModel.endTime)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Now',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isUpcoming)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'Upcoming',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Location and duration row
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    classModel.campusLocation?.name ?? classModel.location,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(classModel.startTime, classModel.endTime),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            // Instructor/Faculty info
            if (classModel.facultyName != null ||
                classModel.instructorOrRoom.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    classModel.facultyName ?? classModel.instructorOrRoom,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
            // Room info
            if (classModel.campusLocation?.room != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Room ${classModel.campusLocation!.room}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

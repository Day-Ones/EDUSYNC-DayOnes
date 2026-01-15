import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/class.dart';
import '../models/user.dart';
import '../models/location.dart';
import '../models/schedule.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/location_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_overlay.dart';
import 'add_edit_class_screen.dart';
import 'add_edit_schedule_screen.dart';
import 'class_details_screen.dart';
import 'join_class_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});
  static const routeName = '/classes';

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  String _searchQuery = '';
  FacultyStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isStudent = user?.userType == UserType.student;

    // Adjust tabs based on user type
    final tabs = isStudent
        ? const [
            Tab(text: 'My Classes'),
            Tab(text: 'Schedule'),
            Tab(text: 'Faculty'),
          ]
        : const [
            Tab(text: 'My Classes'),
            Tab(text: 'Schedule'),
            Tab(text: 'Location'),
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Classes',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClassesTab(context, isStudent),
          _buildScheduleTab(context),
          isStudent
              ? _buildFacultyTrackerTab(context)
              : _buildLocationSettingsTab(context),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          // Hide FAB on Location/Faculty tab (index 2)
          if (_tabController.index == 2) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () {
              // Show options based on current tab
              if (_tabController.index == 0) {
                // Classes tab
                if (isStudent) {
                  Navigator.pushNamed(context, JoinClassScreen.routeName);
                } else {
                  Navigator.pushNamed(context, AddEditClassScreen.routeName);
                }
              } else if (_tabController.index == 1) {
                // Schedule tab
                Navigator.pushNamed(context, AddEditScheduleScreen.routeName,
                    arguments: _selectedDay);
              }
            },
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }

  // ==================== CLASSES TAB ====================
  Widget _buildClassesTab(BuildContext context, bool isStudent) {
    final classProvider = context.watch<ClassProvider>();
    final classes = classProvider.classes;
    final enrolledClasses = classProvider.enrolledClasses;
    final allClasses = [...classes, ...enrolledClasses];

    if (classProvider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EduSyncLoadingIndicator(size: 50),
            const SizedBox(height: 16),
            Text(
              'Loading classes...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (allClasses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isStudent ? 'No classes yet' : 'No classes created',
              style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                isStudent
                    ? JoinClassScreen.routeName
                    : AddEditClassScreen.routeName,
              ),
              icon: Icon(isStudent ? Icons.group_add : Icons.add),
              label: Text(isStudent ? 'Join a Class' : 'Create Class'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allClasses.length,
      itemBuilder: (context, index) {
        final classItem = allClasses[index];
        final isEnrolled = enrolledClasses.any((c) => c.id == classItem.id);
        return _buildClassCard(classItem, isEnrolled, isStudent);
      },
    );
  }

  Widget _buildClassCard(
      ClassModel classItem, bool isEnrolled, bool isStudent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          ClassDetailsScreen.routeName,
          arguments: classItem,
        ),
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
                backgroundColor: classItem.color.withOpacity(0.2),
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
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isEnrolled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Enrolled',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_formatTime(classItem.startTime)} - ${_formatTime(classItem.endTime)}',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _formatDays(classItem.daysOfWeek),
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey[500]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (classItem.facultyName != null && isStudent) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              classItem.facultyName!,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (classItem.campusLocation != null)
                Flexible(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: Colors.grey[400]),
                        Text(
                          classItem.campusLocation!.room ??
                              classItem.campusLocation!.name,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SCHEDULE TAB ====================
  Widget _buildScheduleTab(BuildContext context) {
    final scheduleProvider = context.watch<ScheduleProvider>();
    final schedulesForDay = scheduleProvider.getSchedulesForDate(_selectedDay);

    return Column(
      children: [
        // Calendar
        Container(
          color: Colors.white,
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) =>
                setState(() => _calendarFormat = format),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: true,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle: const TextStyle(color: AppColors.primary),
            ),
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(
                  color: Color(0xFF90CAF9), shape: BoxShape.circle),
            ),
          ),
        ),
        // Date header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                _formatDate(_selectedDay),
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${schedulesForDay.length} events',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        // Schedule list
        Expanded(
          child: schedulesForDay.isEmpty
              ? _buildEmptySchedule()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: schedulesForDay.length,
                  itemBuilder: (context, index) =>
                      _buildScheduleCard(schedulesForDay[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptySchedule() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No events scheduled',
              style: GoogleFonts.inter(color: Colors.grey[600])),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AddEditScheduleScreen.routeName,
              arguments: _selectedDay,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Event'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(ScheduleModel schedule) {
    return Dismissible(
      key: Key(schedule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Event'),
            content: const Text('Are you sure?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) =>
          context.read<ScheduleProvider>().deleteSchedule(schedule.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => Navigator.pushNamed(
              context, AddEditScheduleScreen.routeName,
              arguments: schedule),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: schedule.color, width: 4)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatTime(schedule.startTime),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    Text(_formatTime(schedule.endTime),
                        style: GoogleFonts.inter(
                            color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          decoration: schedule.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (schedule.location != null)
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(schedule.location!,
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                    ],
                  ),
                ),
                Checkbox(
                  value: schedule.isCompleted,
                  onChanged: (_) => context
                      .read<ScheduleProvider>()
                      .toggleComplete(schedule.id),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== FACULTY TRACKER TAB (Students) ====================
  Widget _buildFacultyTrackerTab(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final allFaculty = locationProvider.facultyLocations;
    final filteredFaculty = _filterFaculty(allFaculty);
    filteredFaculty.sort((a, b) => a.status.index.compareTo(b.status.index));

    return Column(
      children: [
        // Search and filters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search faculty...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusFilterChip(null, 'All'),
                    _buildStatusFilterChip(FacultyStatus.onCampus, 'On Campus'),
                    _buildStatusFilterChip(FacultyStatus.nearby, 'Nearby'),
                    _buildStatusFilterChip(FacultyStatus.enRoute, 'En Route'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildStatBadge(
                  allFaculty
                      .where((f) => f.status == FacultyStatus.onCampus)
                      .length,
                  'On Campus',
                  Colors.green),
              const SizedBox(width: 8),
              _buildStatBadge(
                  allFaculty
                      .where((f) => f.status == FacultyStatus.enRoute)
                      .length,
                  'En Route',
                  Colors.orange),
              const Spacer(),
              Text('${filteredFaculty.length} faculty',
                  style: GoogleFonts.inter(color: Colors.grey[600])),
            ],
          ),
        ),
        // Faculty list
        Expanded(
          child: filteredFaculty.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search,
                          size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No faculty found',
                          style: GoogleFonts.inter(color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => locationProvider.refreshFacultyLocations(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredFaculty.length,
                    itemBuilder: (context, index) =>
                        _buildFacultyCard(filteredFaculty[index]),
                  ),
                ),
        ),
      ],
    );
  }

  List<FacultyLocationModel> _filterFaculty(
      List<FacultyLocationModel> faculty) {
    return faculty.where((f) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!f.facultyName.toLowerCase().contains(query) &&
            !(f.department?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }
      if (_selectedStatus != null && f.status != _selectedStatus) return false;
      return true;
    }).toList();
  }

  Widget _buildStatusFilterChip(FacultyStatus? status, String label) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedStatus = status),
        selectedColor: AppColors.primary.withOpacity(0.2),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          color: isSelected ? AppColors.primary : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildStatBadge(int count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$count $label',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildFacultyCard(FacultyLocationModel faculty) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showFacultyDetails(faculty),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      faculty.facultyName
                          .split(' ')
                          .map((n) => n[0])
                          .take(2)
                          .join(),
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: faculty.statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(faculty.facultyName,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    if (faculty.department != null)
                      Text(faculty.department!,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey[600])),
                    Row(
                      children: [
                        Icon(faculty.statusIcon,
                            size: 14, color: faculty.statusColor),
                        const SizedBox(width: 4),
                        Text(faculty.statusText,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: faculty.statusColor)),
                      ],
                    ),
                  ],
                ),
              ),
              if (faculty.estimatedMinutes != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Text('~${faculty.estimatedMinutes}',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange[700])),
                      Text('min',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: Colors.orange[700])),
                    ],
                  ),
                )
              else if (faculty.status == FacultyStatus.onCampus)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.check_circle,
                      color: Colors.green[700], size: 24),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFacultyDetails(FacultyLocationModel faculty) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                        faculty.facultyName
                            .split(' ')
                            .map((n) => n[0])
                            .take(2)
                            .join(),
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(faculty.facultyName,
                            style: GoogleFonts.inter(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        if (faculty.department != null)
                          Text(faculty.department!,
                              style:
                                  GoogleFonts.inter(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: faculty.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(faculty.statusIcon,
                        color: faculty.statusColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(faculty.statusText,
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: faculty.statusColor)),
                          if (faculty.lastUpdated != null)
                            Text(
                                'Updated ${_formatTimeAgo(faculty.lastUpdated!)}',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    if (faculty.estimatedMinutes != null)
                      Column(
                        children: [
                          Text('~${faculty.estimatedMinutes}',
                              style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: faculty.statusColor)),
                          Text('min',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: faculty.statusColor)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (faculty.officeLocation != null)
                _buildDetailRow(
                    Icons.location_on, 'Office', faculty.officeLocation!),
              if (faculty.officeHours != null)
                _buildDetailRow(
                    Icons.access_time, 'Office Hours', faculty.officeHours!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== LOCATION SETTINGS TAB (Faculty) ====================
  Widget _buildLocationSettingsTab(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final position = locationProvider.currentPosition;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Card
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  locationProvider.isSharing
                      ? Icons.location_on
                      : Icons.location_off,
                  size: 60,
                  color:
                      locationProvider.isSharing ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  locationProvider.isSharing
                      ? 'Location Sharing Active'
                      : 'Location Sharing Off',
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  locationProvider.isSharing
                      ? 'Students can see your proximity to campus'
                      : 'Your location is private',
                  style: GoogleFonts.inter(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => locationProvider.toggleSharing(),
                    icon: Icon(locationProvider.isSharing
                        ? Icons.location_off
                        : Icons.location_on),
                    label: Text(locationProvider.isSharing
                        ? 'Stop Sharing'
                        : 'Start Sharing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: locationProvider.isSharing
                          ? Colors.red
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Current Status
        if (locationProvider.isSharing && position != null)
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Status',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.location_on,
                            color: Colors.green, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sharing Location',
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green)),
                            Text('Students can see your status',
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        if (!locationProvider.hasPermission)
          Card(
            elevation: 2,
            color: Colors.orange[50],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Permission Required',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[900])),
                        Text('Enable location access to share',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.orange[800])),
                      ],
                    ),
                  ),
                  TextButton(
                      onPressed: () => locationProvider.requestPermission(),
                      child: const Text('Enable')),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Info Card
        Card(
          elevation: 1,
          color: Colors.blue[50],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text('How it works',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[900])),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoItem(Icons.visibility, 'Students see your status',
                    'On Campus, Nearby, En Route, or Away'),
                const SizedBox(height: 8),
                _buildInfoItem(Icons.timer, 'Estimated arrival',
                    'Shown when en route to campus'),
                const SizedBox(height: 8),
                _buildInfoItem(Icons.security, 'Privacy protected',
                    'Only proximity shared, not exact location'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blue[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900])),
              Text(subtitle,
                  style:
                      GoogleFonts.inter(fontSize: 12, color: Colors.blue[700])),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== HELPER METHODS ====================
  String _formatTime(TimeOfDay time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDays(List<int> days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => dayNames[d - 1]).join(', ');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day)
      return 'Today';
    final tomorrow = now.add(const Duration(days: 1));
    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) return 'Tomorrow';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }
}

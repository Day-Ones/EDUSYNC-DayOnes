import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/class.dart';
import '../models/user.dart';
import '../models/attendance.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../theme/app_theme.dart';
import '../services/faculty_tracking_service.dart';
import '../services/attendance_time_service.dart';
import '../widgets/loading_overlay.dart';
import 'add_edit_class_screen.dart';
import 'student_list_screen.dart';
import 'attendance_scanner_screen.dart';
import 'manage_officers_screen.dart';
import 'edit_schedule_officer_screen.dart';

class ClassDetailsScreen extends StatefulWidget {
  const ClassDetailsScreen({super.key});
  static const routeName = '/class-details';

  @override
  State<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends State<ClassDetailsScreen> {
  bool _hasCheckedInToday = false;
  bool _checkingAttendance = true;
  AttendanceStatus? _todayStatus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkTodayAttendance();
  }

  Future<void> _checkTodayAttendance() async {
    final argClassModel =
        ModalRoute.of(context)?.settings.arguments as ClassModel?;
    if (argClassModel == null) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;

    if (user == null || user.userType == UserType.faculty) {
      setState(() => _checkingAttendance = false);
      return;
    }

    try {
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final recordId = '${argClassModel.id}_${user.id}_$dateKey';

      final doc = await FirebaseFirestore.instance
          .collection('attendance_records')
          .doc(recordId)
          .get();

      if (mounted) {
        setState(() {
          _hasCheckedInToday = doc.exists;
          if (doc.exists) {
            final data = doc.data();
            final statusStr = data?['status'] as String?;
            _todayStatus = AttendanceStatus.values.firstWhere(
              (e) => e.name == statusStr,
              orElse: () => AttendanceStatus.present,
            );
          }
          _checkingAttendance = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _checkingAttendance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    // Handle both ClassModel and String (classId) arguments
    ClassModel? argClassModel;
    if (args is ClassModel) {
      argClassModel = args;
    } else if (args is String) {
      // If a String classId was passed, look up the class from provider
      final classProvider = context.read<ClassProvider>();
      argClassModel = classProvider.getClassById(args);
    }

    if (argClassModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Class Details')),
        body: const Center(child: Text('Class not found')),
      );
    }

    final auth = context.watch<AuthProvider>();
    final classProvider = context.watch<ClassProvider>();
    final classModel = classProvider.classes.firstWhere(
      (c) => c.id == argClassModel!.id,
      orElse: () => classProvider.enrolledClasses.firstWhere(
        (c) => c.id == argClassModel!.id,
        orElse: () => argClassModel!,
      ),
    );

    final user = auth.user;
    final isFaculty = user?.userType == UserType.faculty;
    final isOwner = classModel.userId == user?.id;
    final isEnrolled = classModel.enrolledStudentIds.contains(user?.id);
    final isOfficer = classModel.officerIds.contains(user?.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Modern Sliver App Bar with Hero Header
          _buildSliverAppBar(context, classModel, isOwner, classProvider),

          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Quick Info Pills
                _buildQuickInfoSection(classModel),

                // Class Reminders Toggle
                _buildRemindersToggle(context, classModel, classProvider),

                // Attendance Status Card (for students)
                if (!isFaculty && isEnrolled)
                  _buildAttendanceStatusCard(classModel),

                // Instructor Card
                if (classModel.facultyName != null)
                  _buildInstructorCard(classModel, isFaculty),

                // Location Card
                if (classModel.campusLocation != null ||
                    classModel.location.isNotEmpty)
                  _buildLocationCard(classModel),

                // Quick Actions Grid
                _buildQuickActionsSection(
                  context,
                  classModel,
                  isOwner,
                  isFaculty,
                  isEnrolled,
                  isOfficer,
                ),

                // Invite Code Section (Faculty only)
                if (isOwner && classModel.inviteCode != null)
                  _buildInviteCodeCard(context, classModel),

                // Leave Class Button (for enrolled students)
                if (!isFaculty && isEnrolled)
                  _buildLeaveClassButton(context, classModel, classProvider),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ClassModel classModel,
      bool isOwner, ClassProvider classProvider) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      stretch: true,
      backgroundColor: classModel.color,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
      ),
      actions: [
        if (isOwner) ...[
          _buildAppBarAction(
            icon: Icons.edit_rounded,
            onTap: () => Navigator.pushNamed(
                context, AddEditClassScreen.routeName,
                arguments: classModel),
          ),
          _buildAppBarAction(
            icon: Icons.more_vert_rounded,
            onTap: () => _showMoreOptions(context, classModel, classProvider),
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                classModel.color,
                classModel.color.withOpacity(0.8),
                classModel.color
                    .withBlue((classModel.color.blue + 30).clamp(0, 255)),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 44, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Class Name
                  Text(
                    classModel.name,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Schedule Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          '${_formatTime(classModel.startTime)} - ${_formatTime(classModel.endTime)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarAction(
      {required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildQuickInfoSection(ClassModel classModel) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Days Pill
          Expanded(
            child: _QuickInfoPill(
              icon: Icons.calendar_today_rounded,
              label: 'Days',
              value: _formatDaysShort(classModel.daysOfWeek),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          // Students Pill
          Expanded(
            child: _QuickInfoPill(
              icon: Icons.people_rounded,
              label: 'Students',
              value: '${classModel.enrolledStudentIds.length}',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          // Duration Pill
          Expanded(
            child: _QuickInfoPill(
              icon: Icons.timelapse_rounded,
              label: 'Duration',
              value: _calculateDuration(classModel),
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersToggle(BuildContext context, ClassModel classModel,
      ClassProvider classProvider) {
    final isEnabled = classModel.alerts.isNotEmpty &&
        classModel.alerts.any((a) => a.isEnabled);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isEnabled ? AppColors.primary : Colors.grey)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: isEnabled ? AppColors.primary : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enable Class Reminders',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.9,
              child: Switch(
                value: isEnabled,
                onChanged: (value) async {
                  final alerts = value
                      ? [
                          AlertModel(
                              timeBefore: const Duration(minutes: 15),
                              isEnabled: true)
                        ]
                      : <AlertModel>[];
                  final updatedClass = ClassModel(
                    id: classModel.id,
                    userId: classModel.userId,
                    name: classModel.name,
                    daysOfWeek: classModel.daysOfWeek,
                    startTime: classModel.startTime,
                    endTime: classModel.endTime,
                    instructorOrRoom: classModel.instructorOrRoom,
                    location: classModel.location,
                    color: classModel.color,
                    alerts: alerts,
                    isModifiedLocally: true,
                    lastSyncedAt: classModel.lastSyncedAt,
                    inviteCode: classModel.inviteCode,
                    facultyId: classModel.facultyId,
                    facultyName: classModel.facultyName,
                    campusLocation: classModel.campusLocation,
                    enrolledStudentIds: classModel.enrolledStudentIds,
                    lateGracePeriodMinutes: classModel.lateGracePeriodMinutes,
                    absentGracePeriodMinutes:
                        classModel.absentGracePeriodMinutes,
                    officerIds: classModel.officerIds,
                  );
                  await classProvider.addOrUpdate(updatedClass);
                },
                activeColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStatusCard(ClassModel classModel) {
    if (_checkingAttendance) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final now = DateTime.now();
    final canCheckIn = AttendanceTimeService.canCheckIn(classModel, now);

    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;
    bool isActionable;
    Widget? actionWidget;

    if (_hasCheckedInToday) {
      if (_todayStatus == AttendanceStatus.late) {
        statusColor = Colors.orange;
        statusIcon = Icons.watch_later_rounded;
        statusTitle = 'Checked In - Late';
        statusSubtitle = 'You made it! Try to be earlier next time.';
        isActionable = false;
      } else {
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusTitle = 'Present';
        statusSubtitle = 'Great job! You\'re on time today.';
        isActionable = false;
      }
    } else if (canCheckIn) {
      statusColor = AppColors.primary;
      statusIcon = Icons.qr_code_scanner_rounded;
      statusTitle = 'Ready to Check In';
      statusSubtitle = 'Scan the QR code to mark your attendance';
      isActionable = true;
      actionWidget = ElevatedButton(
        onPressed: () => Navigator.pushNamed(
          context,
          AttendanceScannerScreen.routeName,
          arguments: classModel,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Scan QR', style: TextStyle(fontSize: 13)),
      );
    } else {
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
      statusTitle = 'Absent';
      statusSubtitle = 'Check-in window has closed for today.';
      isActionable = false;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withOpacity(0.1),
              statusColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusTitle,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    statusSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (actionWidget != null) actionWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorCard(ClassModel classModel, bool isFaculty) {
    if (isFaculty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: _ModernInfoCard(
        title: 'Instructor',
        child: _FacultyETAWidget(classModel: classModel),
      ),
    );
  }

  Widget _buildLocationCard(ClassModel classModel) {
    final hasLocation = classModel.campusLocation != null;
    final locationName =
        hasLocation ? classModel.campusLocation!.name : classModel.location;
    final building = hasLocation ? classModel.campusLocation!.building : null;
    final room = hasLocation
        ? classModel.campusLocation!.room
        : classModel.instructorOrRoom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: _ModernInfoCard(
        title: 'Location',
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.success.withOpacity(0.2),
                    AppColors.success.withOpacity(0.1)
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on_rounded,
                  color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locationName.isNotEmpty ? locationName : 'Not specified',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (building != null && building.isNotEmpty ||
                      room != null && room.isNotEmpty)
                    Row(
                      children: [
                        if (building != null && building.isNotEmpty) ...[
                          Text(
                            building,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if (room != null && room.isNotEmpty)
                            Text(' • ',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                        ],
                        if (room != null && room.isNotEmpty)
                          Text(
                            'Room $room',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(
    BuildContext context,
    ClassModel classModel,
    bool isOwner,
    bool isFaculty,
    bool isEnrolled,
    bool isOfficer,
  ) {
    final actions = <Widget>[];

    // Faculty Actions
    if (isOwner) {
      actions.add(_QuickActionCard(
        icon: Icons.qr_code_rounded,
        title: 'Attendance',
        subtitle: 'Generate QR code',
        color: AppColors.success,
        onTap: () => Navigator.pushNamed(context, StudentListScreen.routeName,
            arguments: classModel),
      ));

      actions.add(_QuickActionCard(
        icon: Icons.people_rounded,
        title: 'Students',
        subtitle: '${classModel.enrolledStudentIds.length} enrolled',
        color: AppColors.primary,
        onTap: () => Navigator.pushNamed(context, StudentListScreen.routeName,
            arguments: classModel),
      ));

      actions.add(_QuickActionCard(
        icon: Icons.star_rounded,
        title: 'Officers',
        subtitle: '${classModel.officerIds.length} assigned',
        color: Colors.orange,
        onTap: () => Navigator.pushNamed(
            context, ManageOfficersScreen.routeName,
            arguments: classModel),
      ));
    }

    // Officer Actions
    if (!isFaculty && isEnrolled && isOfficer) {
      actions.add(_QuickActionCard(
        icon: Icons.edit_calendar_rounded,
        title: 'Edit Schedule',
        subtitle: 'Officer access',
        color: Colors.orange,
        badge: 'Officer',
        onTap: () => Navigator.pushNamed(
            context, EditScheduleOfficerScreen.routeName,
            arguments: classModel),
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: actions,
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCodeCard(BuildContext context, ClassModel classModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.primary.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.vpn_key_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Class Invite Code',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Share with students to join',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showInviteCodeDialog(context, classModel),
                  icon: const Icon(Icons.qr_code_rounded,
                      color: AppColors.primary),
                  tooltip: 'Show QR Code',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Invite code display
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: classModel.inviteCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text('Code copied to clipboard'),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      classModel.inviteCode!,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.copy_rounded,
                        color: AppColors.primary.withOpacity(0.6), size: 22),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Enrollment status toggle
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: classModel.isEnrollmentOpen
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: classModel.isEnrollmentOpen
                      ? AppColors.success.withOpacity(0.3)
                      : AppColors.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    classModel.isEnrollmentOpen
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    color: classModel.isEnrollmentOpen
                        ? AppColors.success
                        : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classModel.isEnrollmentOpen
                              ? 'Enrollment Open'
                              : 'Enrollment Closed',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: classModel.isEnrollmentOpen
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        Text(
                          classModel.isEnrollmentOpen
                              ? 'Students can join this class'
                              : 'No new students can join',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: classModel.isEnrollmentOpen,
                    onChanged: (value) =>
                        _toggleEnrollment(context, classModel, value),
                    activeColor: AppColors.success,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleEnrollment(
      BuildContext context, ClassModel classModel, bool isOpen) async {
    final classProvider = context.read<ClassProvider>();

    final updatedClass = classModel.copyWith(
      isEnrollmentOpen: isOpen,
      isModifiedLocally: true,
    );

    await classProvider.addOrUpdate(updatedClass);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(isOpen
                  ? 'Enrollment is now open'
                  : 'Enrollment is now closed'),
            ],
          ),
          backgroundColor: isOpen ? AppColors.success : AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildLeaveClassButton(BuildContext context, ClassModel classModel,
      ClassProvider classProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: TextButton.icon(
        onPressed: () =>
            _showLeaveClassDialog(context, classModel, classProvider),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Leave Class'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.error,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // Helper Methods
  void _showMoreOptions(BuildContext context, ClassModel classModel,
      ClassProvider classProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.delete_rounded, color: AppColors.error),
                ),
                title: Text('Delete Class',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: AppColors.error)),
                subtitle: Text('This action cannot be undone',
                    style: GoogleFonts.inter(fontSize: 12)),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  // Use the original context from the screen, not the bottom sheet context
                  _showDeleteConfirmation(context, classModel, classProvider);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context,
      ClassModel classModel, ClassProvider classProvider) async {
    final enrolledCount = classModel.enrolledStudentIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_rounded,
                  color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Delete Class'),
          ],
        ),
        content: Text(
          enrolledCount > 0
              ? 'This will unenroll all $enrolledCount students and permanently delete this class.'
              : 'This will permanently delete this class.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Delete the class
    await classProvider.delete(classModel.id);

    // Navigate back and show success message
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Class deleted successfully')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showLeaveClassDialog(BuildContext context,
      ClassModel classModel, ClassProvider classProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Class'),
        content: const Text(
            'Are you sure you want to leave this class? You can rejoin later with the invite code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await classProvider.leaveClass(classModel.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the class')),
        );
      }
    }
  }

  void _showInviteCodeDialog(BuildContext context, ClassModel classModel) {
    final code = classModel.inviteCode!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Share Class',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Students can scan this QR code or enter the invite code to join',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: QrImageView(
                    data: code,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.primary,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Invite code
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.05)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      code,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Code copied!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      child: Icon(Icons.copy_rounded,
                          color: AppColors.primary.withOpacity(0.6), size: 20),
                    ),
                  ],
                ),
              ),

              // Enrollment status indicator
              if (!classModel.isEnrollmentOpen) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Enrollment is closed. Students cannot join.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDaysShort(List<int> days) {
    const dayNames = ['M', 'T', 'W', 'Th', 'F', 'Sa', 'Su'];
    return days.map((d) => dayNames[d - 1]).join(' · ');
  }

  String _calculateDuration(ClassModel classModel) {
    final startMinutes =
        classModel.startTime.hour * 60 + classModel.startTime.minute;
    final endMinutes = classModel.endTime.hour * 60 + classModel.endTime.minute;
    final duration = endMinutes - startMinutes;
    if (duration >= 60) {
      final hours = duration ~/ 60;
      final mins = duration % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return '${duration}m';
  }
}

// ==================== REUSABLE WIDGETS ====================

class _QuickInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickInfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernInfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ModernInfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge!,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== FACULTY ETA WIDGET ====================

class _FacultyETAWidget extends StatelessWidget {
  final ClassModel classModel;

  const _FacultyETAWidget({required this.classModel});

  @override
  Widget build(BuildContext context) {
    if (classModel.facultyId == null) {
      return _buildSimpleInstructorRow();
    }

    final trackingService = FacultyTrackingService();
    final now = DateTime.now();
    final classStartMinutes =
        classModel.startTime.hour * 60 + classModel.startTime.minute;
    final nowMinutes = now.hour * 60 + now.minute;
    final minutesUntilClass = classStartMinutes - nowMinutes;
    final isClassToday = classModel.daysOfWeek.contains(now.weekday);
    final showETA =
        isClassToday && minutesUntilClass > -30 && minutesUntilClass <= 60;

    if (!showETA) {
      return _buildSimpleInstructorRow();
    }

    return StreamBuilder<FacultyLocation?>(
      stream: trackingService.getFacultyLocationStream(classModel.facultyId!),
      builder: (context, snapshot) {
        final facultyLocation = snapshot.data;
        ETAInfo? etaInfo;

        if (facultyLocation != null && classModel.campusLocation != null) {
          etaInfo = trackingService.calculateETA(
              facultyLocation, classModel.campusLocation!);
        }

        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.2),
                    Colors.blue.withOpacity(0.1)
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classModel.facultyName ?? 'Unknown',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (etaInfo != null)
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 3),
                        Text(
                          '${etaInfo.formattedDistance} away',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (etaInfo != null)
              _buildETABadge(etaInfo)
            else if (snapshot.connectionState == ConnectionState.waiting)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Location off',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSimpleInstructorRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.2),
                Colors.blue.withOpacity(0.1)
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person_rounded, color: Colors.blue, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            classModel.facultyName ?? 'Unknown',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildETABadge(ETAInfo etaInfo) {
    final isNear = etaInfo.etaMinutes <= 5;
    final color = isNear ? AppColors.success : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNear ? Icons.check_circle_rounded : Icons.directions_car_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            etaInfo.formattedETA,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

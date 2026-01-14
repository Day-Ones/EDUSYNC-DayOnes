import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/class.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/location_provider.dart';
import '../models/location.dart';
import '../services/faculty_tracking_service.dart';
import 'add_edit_class_screen.dart';
import 'student_list_screen.dart';
import 'attendance_scanner_screen.dart';

class ClassDetailsScreen extends StatelessWidget {
  const ClassDetailsScreen({super.key});
  static const routeName = '/class-details';

  @override
  Widget build(BuildContext context) {
    final classModel = ModalRoute.of(context)?.settings.arguments as ClassModel?;
    if (classModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Class Details')),
        body: const Center(child: Text('Class not found')),
      );
    }

    final auth = context.watch<AuthProvider>();
    final classProvider = context.watch<ClassProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final user = auth.user;
    final isFaculty = user?.userType == UserType.faculty;
    final isOwner = classModel.userId == user?.id;

    // Get faculty location status if student
    FacultyLocationModel? facultyLocation;
    if (!isFaculty && classModel.facultyId != null) {
      try {
        facultyLocation = locationProvider.facultyLocations
            .firstWhere((f) => f.facultyId == classModel.facultyId);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          classModel.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: classModel.color,
        foregroundColor: Colors.white,
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.pushNamed(
                context,
                AddEditClassScreen.routeName,
                arguments: classModel,
              ),
            ),
          if (isOwner && classModel.inviteCode != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _showInviteCodeDialog(context, classModel.inviteCode!),
            ),
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Class'),
                      content: Text(
                        classModel.enrolledStudentIds.isNotEmpty
                            ? 'This class has ${classModel.enrolledStudentIds.length} enrolled students. Are you sure you want to delete it?'
                            : 'Are you sure you want to delete this class?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await classProvider.delete(classModel.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Class deleted')),
                      );
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Class', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with color
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: classModel.color.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classModel.name,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatTime(classModel.startTime)} - ${_formatTime(classModel.endTime)}',
                        style: GoogleFonts.albertSans(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        _formatDays(classModel.daysOfWeek),
                        style: GoogleFonts.albertSans(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Faculty Status (for students) with ETA
            if (!isFaculty && classModel.facultyName != null && classModel.facultyId != null) ...[
              _FacultyETAWidget(classModel: classModel),
            ],

            // Campus Location
            if (classModel.campusLocation != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.location_on, color: Colors.green),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    classModel.campusLocation!.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (classModel.campusLocation!.building != null)
                                    Text(
                                      classModel.campusLocation!.building!,
                                      style: GoogleFonts.albertSans(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if (classModel.campusLocation!.room != null)
                                    Text(
                                      'Room ${classModel.campusLocation!.room}',
                                      style: GoogleFonts.albertSans(
                                        fontSize: 14,
                                        color: Colors.grey[600],
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
              ),

            // Class Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (classModel.location.isNotEmpty) ...[
                    _buildInfoRow(Icons.business, 'Building', classModel.location),
                    const SizedBox(height: 12),
                  ],
                  if (classModel.instructorOrRoom.isNotEmpty) ...[
                    _buildInfoRow(
                      isFaculty ? Icons.meeting_room : Icons.person,
                      isFaculty ? 'Room' : 'Instructor',
                      classModel.instructorOrRoom,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (classModel.notes.isNotEmpty) ...[
                    _buildInfoRow(Icons.notes, 'Notes', classModel.notes),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),

            // Attendance Section (Faculty only - always show)
            if (isOwner) ...[
              // Show enrolled students count if any
              if (classModel.enrolledStudentIds.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Enrolled Students (${classModel.enrolledStudentIds.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          StudentListScreen.routeName,
                          arguments: classModel,
                        ),
                        icon: const Icon(Icons.people, size: 18),
                        label: const Text('View All'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Attendance Action Card - always show for faculty
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 2,
                  color: Colors.green.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      StudentListScreen.routeName,
                      arguments: classModel,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.qr_code, color: Colors.green, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Check Attendance',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Generate QR code for students to scan',
                                  style: GoogleFonts.albertSans(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Student Attendance Check-in (for enrolled students)
            if (!isFaculty && classModel.enrolledStudentIds.contains(user?.id)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 2,
                  color: const Color(0xFF2196F3).withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(context, AttendanceScannerScreen.routeName),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.qr_code_scanner, color: Color(0xFF2196F3), size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Check-in Attendance',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Scan QR code to mark your attendance',
                                  style: GoogleFonts.albertSans(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Invite Code Section (Faculty only)
            if (isOwner && classModel.inviteCode != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 2,
                  color: const Color(0xFF2196F3).withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vpn_key, color: Color(0xFF2196F3)),
                            const SizedBox(width: 8),
                            Text(
                              'Invite Code',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _showInviteCodeDialog(context, classModel.inviteCode!),
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Share'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2196F3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                classModel.inviteCode!,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 4,
                                  color: const Color(0xFF2196F3),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Color(0xFF2196F3)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: classModel.inviteCode!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Code copied!')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Leave Class Button (for enrolled students)
            if (!isFaculty && classModel.enrolledStudentIds.contains(user?.id))
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Leave Class'),
                        content: const Text('Are you sure you want to leave this class?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Leave', style: TextStyle(color: Colors.red)),
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
                  },
                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                  label: const Text('Leave Class', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.albertSans(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showInviteCodeDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.share, color: Color(0xFF2196F3)),
            const SizedBox(width: 8),
            Text('Share Invite Code', style: GoogleFonts.poppins(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share this code with your students:',
              style: GoogleFonts.albertSans(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2196F3)),
              ),
              child: Text(
                code,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
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

  String _formatDays(List<int> days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => dayNames[d - 1]).join(', ');
  }
}

/// Widget to show faculty ETA for students
class _FacultyETAWidget extends StatelessWidget {
  final ClassModel classModel;
  
  const _FacultyETAWidget({required this.classModel});
  
  @override
  Widget build(BuildContext context) {
    final trackingService = FacultyTrackingService();
    
    // Check if class is within 1 hour
    final now = DateTime.now();
    final classStartMinutes = classModel.startTime.hour * 60 + classModel.startTime.minute;
    final nowMinutes = now.hour * 60 + now.minute;
    final minutesUntilClass = classStartMinutes - nowMinutes;
    final isClassToday = classModel.daysOfWeek.contains(now.weekday);
    final showETA = isClassToday && minutesUntilClass > -30 && minutesUntilClass <= 60;
    
    if (!showETA || classModel.facultyId == null) {
      // Just show faculty name without ETA
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instructor',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        classModel.facultyName ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show ETA tracking
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<FacultyLocation?>(
            stream: trackingService.getFacultyLocationStream(classModel.facultyId!),
            builder: (context, snapshot) {
              final facultyLocation = snapshot.data;
              ETAInfo? etaInfo;
              
              if (facultyLocation != null && classModel.campusLocation != null) {
                etaInfo = trackingService.calculateETA(
                  facultyLocation,
                  classModel.campusLocation!,
                );
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instructor',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              classModel.facultyName ?? 'Unknown',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (etaInfo != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: etaInfo.etaMinutes <= 5 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_car,
                                size: 16,
                                color: etaInfo.etaMinutes <= 5 ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                etaInfo.formattedETA,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: etaInfo.etaMinutes <= 5 ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (snapshot.connectionState == ConnectionState.waiting) ...[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Location unavailable',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (etaInfo != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${etaInfo.formattedDistance} away',
                          style: GoogleFonts.albertSans(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (etaInfo.isStale)
                          Text(
                            'Last updated ${_formatLastUpdated(etaInfo.lastUpdated)}',
                            style: GoogleFonts.albertSans(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  String _formatLastUpdated(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

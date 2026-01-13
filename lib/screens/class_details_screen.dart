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
import 'add_edit_class_screen.dart';

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

            // Faculty Status (for students)
            if (!isFaculty && classModel.facultyName != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instructor',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
                              child: Text(
                                classModel.facultyName!.split(' ').map((n) => n[0]).take(2).join(),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2196F3),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    classModel.facultyName!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (facultyLocation != null)
                                    Row(
                                      children: [
                                        Icon(
                                          facultyLocation.statusIcon,
                                          size: 14,
                                          color: facultyLocation.statusColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          facultyLocation.statusText,
                                          style: GoogleFonts.albertSans(
                                            fontSize: 13,
                                            color: facultyLocation.statusColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            if (facultyLocation?.estimatedMinutes != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '~${facultyLocation!.estimatedMinutes}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                    Text(
                                      'min',
                                      style: GoogleFonts.albertSans(
                                        fontSize: 10,
                                        color: Colors.orange[700],
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

            // Enrolled Students (Faculty only)
            if (isOwner && classModel.enrolledStudentIds.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Enrolled Students (${classModel.enrolledStudentIds.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: classModel.enrolledStudentIds.length,
                itemBuilder: (context, index) {
                  final studentId = classModel.enrolledStudentIds[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: Text('${index + 1}'),
                      ),
                      title: Text('Student ${index + 1}'),
                      subtitle: Text('ID: ${studentId.substring(0, 8)}...'),
                    ),
                  );
                },
              ),
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

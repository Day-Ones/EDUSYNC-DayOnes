import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/class.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';
import '../services/attendance_time_service.dart';
import '../widgets/connectivity_banner.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});
  static const routeName = '/student-list';

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String _filter = 'total'; // 'total', 'present', 'late', 'absent'
  bool _isInitialized = false;
  String? _currentClassId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final classModel =
        ModalRoute.of(context)?.settings.arguments as ClassModel?;
    if (classModel != null &&
        (!_isInitialized || _currentClassId != classModel.id)) {
      _isInitialized = true;
      _currentClassId = classModel.id;
      final attendanceProvider = context.read<AttendanceProvider>();
      // Load students first, then start listening for real-time updates
      attendanceProvider
          .loadStudentsForClass(
        classModel.id,
        classModel.enrolledStudentIds,
      )
          .then((_) {
        // Start listening for real-time attendance updates after initial load
        attendanceProvider.startListeningToAttendance(
          classModel.id,
          classModel.enrolledStudentIds,
        );
      });
    }
  }

  @override
  void dispose() {
    // Stop listening when leaving the screen
    context.read<AttendanceProvider>().stopListeningToAttendance();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classModel =
        ModalRoute.of(context)?.settings.arguments as ClassModel?;
    if (classModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Students')),
        body: const Center(child: Text('Class not found')),
      );
    }

    final attendanceProvider = context.watch<AttendanceProvider>();
    final allStudents = attendanceProvider.getStudentsForClass(classModel.id);
    final presentStudents = allStudents
        .where((s) =>
            s.isCheckedInToday && s.todayStatus == AttendanceStatus.present)
        .toList();
    final lateStudents = allStudents
        .where(
            (s) => s.isCheckedInToday && s.todayStatus == AttendanceStatus.late)
        .toList();
    final absentStudents =
        allStudents.where((s) => !s.isCheckedInToday).toList();

    // Filter students based on selection
    List<EnrolledStudent> students;
    String filterLabel;
    switch (_filter) {
      case 'present':
        students = presentStudents;
        filterLabel = 'Present Students';
        break;
      case 'late':
        students = lateStudents;
        filterLabel = 'Late Students';
        break;
      case 'absent':
        students = absentStudents;
        filterLabel = 'Absent Students';
        break;
      default:
        students = allStudents;
        filterLabel = 'All Students';
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: classModel.color,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.white),
            tooltip: 'Check Attendance',
            onPressed: () =>
                _showQrCodeDialog(context, classModel, attendanceProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectivityBanner(),
          // Stats Header - Clickable Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: classModel.color.withOpacity(0.1),
            child: Row(
              children: [
                _buildFilterCard('Total', allStudents.length.toString(),
                    Colors.blue, 'total'),
                const SizedBox(width: 8),
                _buildFilterCard('Present', presentStudents.length.toString(),
                    Colors.green, 'present'),
                const SizedBox(width: 8),
                _buildFilterCard('Late', lateStudents.length.toString(),
                    Colors.orange, 'late'),
                const SizedBox(width: 8),
                _buildFilterCard('Absent', absentStudents.length.toString(),
                    Colors.red, 'absent'),
              ],
            ),
          ),

          // Filter Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  filterLabel,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Student List
          Expanded(
            child: students.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _filter == 'absent'
                              ? Icons.check_circle
                              : _filter == 'present'
                                  ? Icons.person_off
                                  : Icons.people_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filter == 'absent'
                              ? 'All students are present!'
                              : _filter == 'present'
                                  ? 'No students present yet'
                                  : 'No students enrolled',
                          style: GoogleFonts.poppins(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: students.length,
                    itemBuilder: (context, index) =>
                        _buildStudentCard(students[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showQrCodeDialog(context, classModel, attendanceProvider),
        backgroundColor: classModel.color,
        icon: const Icon(Icons.qr_code, color: Colors.white),
        label: Text('Check Attendance',
            style: GoogleFonts.poppins(color: Colors.white)),
      ),
    );
  }

  Widget _buildFilterCard(
      String label, String value, Color color, String filterValue) {
    final isSelected = _filter == filterValue;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = filterValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? color.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: isSelected ? 8 : 4,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.albertSans(
                  fontSize: 12,
                  color: isSelected ? color : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(EnrolledStudent student) {
    // Determine color and icon based on attendance status
    Color statusColor;
    String statusText;

    if (!student.isCheckedInToday) {
      statusColor = Colors.red;
      statusText = 'Absent';
    } else if (student.todayStatus == AttendanceStatus.late) {
      statusColor = Colors.orange;
      statusText = 'Late';
    } else {
      statusColor = Colors.green;
      statusText = 'Present';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Text(
                student.name.split(' ').map((n) => n[0]).take(2).join(),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(student.name,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.studentId ?? student.email,
                style: GoogleFonts.albertSans(fontSize: 12)),
            const SizedBox(height: 4),
            if (student.isCheckedInToday && student.checkedInTime != null)
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    '${student.todayStatus == AttendanceStatus.late ? 'Late' : 'Present'} - ${_formatTime(student.checkedInTime!)}',
                    style: GoogleFonts.albertSans(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              )
            else if (student.isCheckedInToday)
              Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    '${student.todayStatus == AttendanceStatus.late ? 'Late' : 'Present'}',
                    style: GoogleFonts.albertSans(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.pending, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Not checked in yet',
                    style: GoogleFonts.albertSans(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusText,
            style: GoogleFonts.albertSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _showQrCodeDialog(BuildContext context, ClassModel classModel,
      AttendanceProvider provider) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    // Check if QR generation is allowed based on time window
    final now = DateTime.now();
    if (!AttendanceTimeService.canGenerateQR(classModel, now)) {
      final message =
          AttendanceTimeService.getCheckInWindowMessage(classModel, now);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Cannot Generate QR',
                    style: GoogleFonts.poppins(fontSize: 18)),
              ),
            ],
          ),
          content: Text(
            message,
            style: GoogleFonts.albertSans(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show loading dialog while generating QR
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final qrData = await provider.generateAttendanceQr(
        classModel.id,
        classModel.name,
        user.id,
        user.fullName,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.qr_code, color: classModel.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Attendance QR',
                    style: GoogleFonts.poppins(fontSize: 18)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Students scan this code to check in',
                  style: GoogleFonts.albertSans(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: classModel.color),
                  ),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  classModel.name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer, size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Valid for 5 minutes',
                      style: GoogleFonts.albertSans(
                          fontSize: 12, color: Colors.orange[700]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showQrCodeDialog(context, classModel, provider);
              },
              child: const Text('Refresh'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style:
                  ElevatedButton.styleFrom(backgroundColor: classModel.color),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating QR: $e')),
      );
    }
  }
}

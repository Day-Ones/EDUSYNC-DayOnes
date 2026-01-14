import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/class.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});
  static const routeName = '/student-list';

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String _filter = 'total'; // 'total', 'present', 'absent'

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final classModel = ModalRoute.of(context)?.settings.arguments as ClassModel?;
    if (classModel != null) {
      context.read<AttendanceProvider>().loadStudentsForClass(
        classModel.id,
        classModel.enrolledStudentIds,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final classModel = ModalRoute.of(context)?.settings.arguments as ClassModel?;
    if (classModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Students')),
        body: const Center(child: Text('Class not found')),
      );
    }

    final attendanceProvider = context.watch<AttendanceProvider>();
    final allStudents = attendanceProvider.getStudentsForClass(classModel.id);
    final presentStudents = allStudents.where((s) => s.isCheckedInToday).toList();
    final absentStudents = allStudents.where((s) => !s.isCheckedInToday).toList();
    
    // Filter students based on selection
    List<EnrolledStudent> students;
    String filterLabel;
    switch (_filter) {
      case 'present':
        students = presentStudents;
        filterLabel = 'Present Students';
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
            onPressed: () => _showQrCodeDialog(context, classModel, attendanceProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Header - Clickable Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: classModel.color.withOpacity(0.1),
            child: Row(
              children: [
                _buildFilterCard('Total', allStudents.length.toString(), Colors.blue, 'total'),
                const SizedBox(width: 12),
                _buildFilterCard('Present', presentStudents.length.toString(), Colors.green, 'present'),
                const SizedBox(width: 12),
                _buildFilterCard('Absent', absentStudents.length.toString(), Colors.red, 'absent'),
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
                          _filter == 'absent' ? Icons.check_circle : 
                          _filter == 'present' ? Icons.person_off : Icons.people_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filter == 'absent' ? 'All students are present!' :
                          _filter == 'present' ? 'No students present yet' :
                          'No students enrolled',
                          style: GoogleFonts.poppins(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: students.length,
                    itemBuilder: (context, index) => _buildStudentCard(students[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQrCodeDialog(context, classModel, attendanceProvider),
        backgroundColor: classModel.color,
        icon: const Icon(Icons.qr_code, color: Colors.white),
        label: Text('Check Attendance', style: GoogleFonts.poppins(color: Colors.white)),
      ),
    );
  }

  Widget _buildFilterCard(String label, String value, Color color, String filterValue) {
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
                color: isSelected ? color.withOpacity(0.2) : Colors.black.withOpacity(0.05),
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
    final isAbsent = !student.isCheckedInToday;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isAbsent ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              child: Text(
                student.name.split(' ').map((n) => n[0]).take(2).join(),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: isAbsent ? Colors.red : Colors.green,
                ),
              ),
            ),
            if (isAbsent)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(student.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.studentId ?? student.email, style: GoogleFonts.albertSans(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.bar_chart, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Attendance: ${student.attendancePercentage.toStringAsFixed(0)}%',
                  style: GoogleFonts.albertSans(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${student.attendedClasses}/${student.totalClasses})',
                  style: GoogleFonts.albertSans(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isAbsent ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isAbsent ? 'Absent' : 'Present',
            style: GoogleFonts.albertSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isAbsent ? Colors.red : Colors.green,
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showQrCodeDialog(BuildContext context, ClassModel classModel, AttendanceProvider provider) {
    final qrData = provider.generateAttendanceQr(classModel.id, classModel.name);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.qr_code, color: classModel.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Attendance QR', style: GoogleFonts.poppins(fontSize: 18)),
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
                    style: GoogleFonts.albertSans(fontSize: 12, color: Colors.orange[700]),
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
            style: ElevatedButton.styleFrom(backgroundColor: classModel.color),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

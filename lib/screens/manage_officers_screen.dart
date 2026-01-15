import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/class.dart';
import '../models/attendance.dart';
import '../providers/class_provider.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class ManageOfficersScreen extends StatefulWidget {
  const ManageOfficersScreen({super.key});
  static const routeName = '/manage-officers';

  @override
  State<ManageOfficersScreen> createState() => _ManageOfficersScreenState();
}

class _ManageOfficersScreenState extends State<ManageOfficersScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<EnrolledStudent> _enrolledStudents = [];
  List<String> _officerIds = [];
  bool _isLoading = true;
  String? _selectedStudentId;

  ClassModel? _classModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ClassModel && _classModel == null) {
      _classModel = args;
      _officerIds = List.from(args.officerIds);
      _loadStudents();
    }
  }

  Future<void> _loadStudents() async {
    if (_classModel == null) return;

    setState(() => _isLoading = true);

    try {
      final students =
          await _firebaseService.getEnrolledStudents(_classModel!.id);
      if (mounted) {
        setState(() {
          _enrolledStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading students: $e')),
        );
      }
    }
  }

  Future<void> _addOfficer(EnrolledStudent student) async {
    if (_classModel == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Officer'),
        content: Text(
          'Are you sure you want to make ${student.name} an officer?\n\n'
          'Officers can update the class schedule (time, days, location, room). '
          'You will be notified when they make changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await _firebaseService.addOfficer(
        classId: _classModel!.id,
        studentId: student.id,
        studentName: student.name,
      );

      if (success) {
        setState(() {
          _officerIds.add(student.id);
        });

        // Update the class model in provider
        if (mounted) {
          final classProvider = context.read<ClassProvider>();
          final updatedClass =
              _classModel!.copyWith(officerIds: List.from(_officerIds));
          await classProvider.addOrUpdate(updatedClass);
          _classModel = updatedClass;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${student.name} is now an officer')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add officer')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _removeOfficer(EnrolledStudent student) async {
    if (_classModel == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Officer'),
        content: Text(
          'Are you sure you want to remove ${student.name} as an officer?\n\n'
          'They will no longer be able to update the class schedule.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await _firebaseService.removeOfficer(
        classId: _classModel!.id,
        studentId: student.id,
      );

      if (success) {
        setState(() {
          _officerIds.remove(student.id);
        });

        // Update the class model in provider
        if (mounted) {
          final classProvider = context.read<ClassProvider>();
          final updatedClass =
              _classModel!.copyWith(officerIds: List.from(_officerIds));
          await classProvider.addOrUpdate(updatedClass);
          _classModel = updatedClass;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${student.name} is no longer an officer')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove officer')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_classModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Officers')),
        body: const Center(child: Text('Class not found')),
      );
    }

    final officers =
        _enrolledStudents.where((s) => _officerIds.contains(s.id)).toList();
    final nonOfficers =
        _enrolledStudents.where((s) => !_officerIds.contains(s.id)).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _classModel!.color,
        elevation: 0,
        title: Text(
          'Manage Officers',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _enrolledStudents.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadStudents,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Info Card
                      Card(
                        color: AppColors.primary.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.info_outline,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Officers can update the class schedule. '
                                  'You will be notified when they make changes.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Current Officers Section
                      if (officers.isNotEmpty) ...[
                        Text(
                          'Current Officers (${officers.length})',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...officers.map((student) => _buildStudentCard(
                              student,
                              isOfficer: true,
                            )),
                        const SizedBox(height: 24),
                      ],

                      // Add Officer Section
                      Text(
                        'Enrolled Students (${nonOfficers.length})',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap a student to make them an officer',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (nonOfficers.isEmpty)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'All enrolled students are officers',
                                  style: GoogleFonts.inter(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...nonOfficers.map((student) => _buildStudentCard(
                              student,
                              isOfficer: false,
                            )),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No students enrolled',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Students need to join the class first\nbefore they can be made officers',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(EnrolledStudent student, {required bool isOfficer}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => isOfficer ? _removeOfficer(student) : _addOfficer(student),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isOfficer
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                child: isOfficer
                    ? const Icon(Icons.star, color: Colors.orange)
                    : Text(
                        student.name.split(' ').map((n) => n[0]).take(2).join(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            student.name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOfficer) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Officer',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      student.studentId ?? student.email,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isOfficer
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline,
                color: isOfficer ? Colors.red : Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

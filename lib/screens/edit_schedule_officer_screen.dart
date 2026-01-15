import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/class.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_overlay.dart';

class EditScheduleOfficerScreen extends StatefulWidget {
  const EditScheduleOfficerScreen({super.key});
  static const routeName = '/edit-schedule-officer';

  @override
  State<EditScheduleOfficerScreen> createState() =>
      _EditScheduleOfficerScreenState();
}

class _EditScheduleOfficerScreenState extends State<EditScheduleOfficerScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();

  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final Set<int> _selectedDays = {};
  final _locationController = TextEditingController();
  final _roomController = TextEditingController();

  ClassModel? _classModel;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ClassModel && _classModel == null) {
      _classModel = args;
      _startTime = args.startTime;
      _endTime = args.endTime;
      _selectedDays.addAll(args.daysOfWeek);
      _locationController.text = args.location;
      _roomController.text = args.instructorOrRoom;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _hasChanges = true;
      });
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
      _hasChanges = true;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    // Validate time
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;

    if (user == null || _classModel == null) return;

    // Check if user is still an officer
    if (!_classModel!.officerIds.contains(user.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are no longer an officer for this class'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Build update map
      final updates = <String, dynamic>{
        'startHour': _startTime.hour,
        'startMinute': _startTime.minute,
        'endHour': _endTime.hour,
        'endMinute': _endTime.minute,
        'daysOfWeek': _selectedDays.toList()..sort(),
        'location': _locationController.text.trim(),
        'instructorOrRoom': _roomController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final success = await _firebaseService.updateClassSchedule(
        classId: _classModel!.id,
        updates: updates,
        officerId: user.id,
        officerName: user.fullName,
        facultyId: _classModel!.facultyId,
        className: _classModel!.name,
      );

      if (success) {
        // Update the class model in the provider
        if (mounted) {
          final classProvider = context.read<ClassProvider>();
          final updatedClass = _classModel!.copyWith(
            startTime: _startTime,
            endTime: _endTime,
            daysOfWeek: _selectedDays.toList()..sort(),
            location: _locationController.text.trim(),
            instructorOrRoom: _roomController.text.trim(),
          );
          await classProvider.addOrUpdate(updatedClass);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Schedule updated! The faculty has been notified.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update schedule'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_classModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Schedule')),
        body: const Center(child: Text('Class not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _classModel!.color,
        title: Text(
          'Edit Schedule',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_hasChanges) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Discard Changes?'),
                  content: const Text(
                      'You have unsaved changes. Are you sure you want to leave?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('Discard',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'As an officer, you can update the class schedule. '
                          'The faculty will be notified of your changes.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Class Name (read-only)
                Text(
                  'Class',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _classModel!.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Time Section
                Text(
                  'Class Time',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeButton(
                        label: 'Start',
                        time: _startTime,
                        onTap: () => _pickTime(true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeButton(
                        label: 'End',
                        time: _endTime,
                        onTap: () => _pickTime(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Days Section
                Text(
                  'Class Days',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDayChip(1, 'Mon'),
                    _buildDayChip(2, 'Tue'),
                    _buildDayChip(3, 'Wed'),
                    _buildDayChip(4, 'Thu'),
                    _buildDayChip(5, 'Fri'),
                    _buildDayChip(6, 'Sat'),
                    _buildDayChip(7, 'Sun'),
                  ],
                ),
                const SizedBox(height: 24),

                // Location Section
                Text(
                  'Building / Location',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Main Building',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.05),
                  ),
                  onChanged: (_) => setState(() => _hasChanges = true),
                ),
                const SizedBox(height: 16),

                // Room Section
                Text(
                  'Room',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _roomController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Room 301',
                    prefixIcon: const Icon(Icons.meeting_room_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.05),
                  ),
                  onChanged: (_) => setState(() => _hasChanges = true),
                ),
                const SizedBox(height: 32),

                // Save Button
                ElevatedButton(
                  onPressed: _hasChanges && !_isLoading ? _saveChanges : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _classModel!.color,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: LoadingCard(message: 'Saving changes...'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeButton({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  _formatTime(time),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayChip(int day, String label) {
    final isSelected = _selectedDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _toggleDay(day),
      selectedColor: _classModel!.color.withOpacity(0.2),
      checkmarkColor: _classModel!.color,
      labelStyle: GoogleFonts.inter(
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        color: isSelected ? _classModel!.color : Colors.grey[700],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

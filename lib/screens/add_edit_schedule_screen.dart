import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/schedule.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';

class AddEditScheduleScreen extends StatefulWidget {
  const AddEditScheduleScreen({super.key});
  static const routeName = '/add-schedule';

  @override
  State<AddEditScheduleScreen> createState() => _AddEditScheduleScreenState();
}

class _AddEditScheduleScreenState extends State<AddEditScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  ScheduleType _scheduleType = ScheduleType.personal;
  Color _selectedColor = AppColors.classPalette.first;
  bool _isRecurring = false;
  final Set<int> _recurringDays = {};
  int _reminderMinutes = 15;

  ScheduleModel? _editingSchedule;
  bool _isEditing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ScheduleModel && !_isEditing) {
      _isEditing = true;
      _editingSchedule = args;
      _titleController.text = args.title;
      _descriptionController.text = args.description;
      _locationController.text = args.location ?? '';
      _selectedDate = args.date;
      _startTime = args.startTime;
      _endTime = args.endTime;
      _scheduleType = args.scheduleType;
      _selectedColor = args.color;
      _isRecurring = args.isRecurring;
      _recurringDays.addAll(args.recurringDays);
      _reminderMinutes = args.reminderMinutes;
    } else if (args is DateTime && !_isEditing) {
      _selectedDate = args;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(bool isStart) async {
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
      });
    }
  }

  void _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final user = auth.user;

    if (user == null) return;

    // Validate time
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    final schedule = ScheduleModel(
      id: _editingSchedule?.id ?? UniqueKey().toString(),
      userId: user.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      scheduleType: _scheduleType,
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      color: _selectedColor,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      isRecurring: _isRecurring,
      recurringDays: _recurringDays.toList(),
      reminderMinutes: _reminderMinutes,
      isCompleted: _editingSchedule?.isCompleted ?? false,
      createdAt: _editingSchedule?.createdAt,
    );

    if (_editingSchedule != null) {
      await scheduleProvider.updateSchedule(schedule);
    } else {
      await scheduleProvider.addSchedule(schedule);
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_editingSchedule != null ? 'Event updated' : 'Event added'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isStudent = auth.user?.userType == UserType.student;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editingSchedule != null ? 'Edit Event' : 'Add Event',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_editingSchedule != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Event'),
                    content: const Text('Are you sure you want to delete this event?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await context.read<ScheduleProvider>().deleteSchedule(_editingSchedule!.id);
                  if (!mounted) return;
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Event Title',
                labelStyle: GoogleFonts.inter(fontSize: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Schedule Type
            Text(
              'Event Type',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildTypeChip(ScheduleType.personal, 'Personal', Icons.person),
                _buildTypeChip(
                  ScheduleType.academic,
                  isStudent ? 'Study' : 'Academic',
                  Icons.school,
                ),
                _buildTypeChip(
                  ScheduleType.office,
                  isStudent ? 'Meeting' : 'Office Hours',
                  Icons.work,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: AppColors.primary),
              title: Text('Date', style: GoogleFonts.inter(fontSize: 14)),
              subtitle: Text(
                _formatDate(_selectedDate),
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectDate,
            ),
            const Divider(),

            // Time Row
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time, color: AppColors.primary),
                    title: Text('Start', style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(
                      _formatTime(_startTime),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    onTap: () => _selectTime(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time_filled, color: AppColors.primary),
                    title: Text('End', style: GoogleFonts.inter(fontSize: 14)),
                    subtitle: Text(
                      _formatTime(_endTime),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    onTap: () => _selectTime(false),
                  ),
                ),
              ],
            ),
            const Divider(),

            // Recurring
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Recurring Event', style: GoogleFonts.inter(fontSize: 16)),
              subtitle: Text(
                'Repeat on selected days',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              value: _isRecurring,
              onChanged: (value) => setState(() => _isRecurring = value),
              activeColor: AppColors.primary,
            ),
            if (_isRecurring) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  return FilterChip(
                    label: Text(labels[index]),
                    selected: _recurringDays.contains(day),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _recurringDays.add(day);
                        } else {
                          _recurringDays.remove(day);
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }),
              ),
            ],
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location (optional)',
                labelStyle: GoogleFonts.inter(fontSize: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: GoogleFonts.inter(fontSize: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Reminder
            Text(
              'Reminder',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildReminderChip(0, 'None'),
                _buildReminderChip(5, '5 min'),
                _buildReminderChip(15, '15 min'),
                _buildReminderChip(30, '30 min'),
                _buildReminderChip(60, '1 hour'),
              ],
            ),
            const SizedBox(height: 16),

            // Color
            Text(
              'Color',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            BlockPicker(
              pickerColor: _selectedColor,
              availableColors: AppColors.classPalette,
              onColorChanged: (color) => setState(() => _selectedColor = color),
              layoutBuilder: (context, colors, child) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((color) => child(color)).toList(),
                );
              },
              itemBuilder: (color, isCurrentColor, changeColor) {
                return GestureDetector(
                  onTap: changeColor,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isCurrentColor
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                    child: isCurrentColor
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _saveSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                _editingSchedule != null ? 'Update Event' : 'Add Event',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(ScheduleType type, String label, IconData icon) {
    final isSelected = _scheduleType == type;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _scheduleType = type),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }

  Widget _buildReminderChip(int minutes, String label) {
    final isSelected = _reminderMinutes == minutes;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _reminderMinutes = minutes),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

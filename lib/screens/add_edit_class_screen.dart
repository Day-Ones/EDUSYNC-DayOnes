import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/class.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../theme/app_theme.dart';

class AddEditClassScreen extends StatefulWidget {
  const AddEditClassScreen({super.key});
  static const routeName = '/add-class';

  @override
  State<AddEditClassScreen> createState() => _AddEditClassScreenState();
}

class _AddEditClassScreenState extends State<AddEditClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _instructor = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  final _roomController = TextEditingController();
  
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  final Set<int> _days = {1, 3, 5};
  Color _color = AppColors.classPalette.first;
  bool _alert24 = true;
  bool _alert12 = false;
  bool _alert2 = true;
  bool _alert15 = true;
  bool _syncToGoogle = true;
  bool _includeAlerts = true;
  bool _hasConflict = false;
  
  // New fields for faculty
  CampusLocationModel? _selectedCampus;
  String? _inviteCode;
  ClassModel? _editingClass;
  bool _isEditing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ClassModel && !_isEditing) {
      _isEditing = true;
      _editingClass = args;
      _name.text = args.name;
      _instructor.text = args.instructorOrRoom;
      _location.text = args.location;
      _notes.text = args.notes;
      _start = args.startTime;
      _end = args.endTime;
      _days.clear();
      _days.addAll(args.daysOfWeek);
      _color = args.color;
      _inviteCode = args.inviteCode;
      _selectedCampus = args.campusLocation;
      if (_selectedCampus != null) {
        _roomController.text = _selectedCampus!.room ?? '';
      }
      
      // Restore alert states from existing class
      _alert24 = args.alerts.any((a) => a.timeBefore.inHours == 24 && a.isEnabled);
      _alert12 = args.alerts.any((a) => a.timeBefore.inHours == 12 && a.isEnabled);
      _alert2 = args.alerts.any((a) => a.timeBefore.inHours == 2 && a.isEnabled);
      _alert15 = args.alerts.any((a) => a.timeBefore.inMinutes == 15 && a.isEnabled);
      _syncToGoogle = args.syncWithGoogle;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _instructor.dispose();
    _location.dispose();
    _notes.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked != null) {
      setState(() {
        if (start) {
          _start = picked;
        } else {
          _end = picked;
        }
        _hasConflict = _start.hour > _end.hour || (_start.hour == _end.hour && _start.minute >= _end.minute);
      });
    }
  }

  void _showInviteCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.share, color: Color(0xFF2196F3)),
            const SizedBox(width: 8),
            Text('Class Invite Code', style: GoogleFonts.poppins(fontSize: 18)),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _inviteCode ?? 'N/A',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF2196F3)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _inviteCode ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Students can use this code to join your class',
              style: GoogleFonts.albertSans(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _inviteCode = ClassModel.generateInviteCode();
              });
              Navigator.pop(context);
              _showInviteCodeDialog();
            },
            child: const Text('Regenerate'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final user = auth.user;
    final isFaculty = user?.userType == UserType.faculty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Class' : 'Add Class'),
        actions: [
          if (isFaculty && _inviteCode != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _showInviteCodeDialog,
              tooltip: 'Share Invite Code',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_hasConflict)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: AppColors.warning),
                        SizedBox(width: 8),
                        Expanded(child: Text('End time must be after start time.')),
                      ],
                    ),
                  ),
                
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Class Name',
                    prefixIcon: Icon(Icons.class_),
                  ),
                  validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                Text('Days', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    return FilterChip(
                      label: Text(labels[index]),
                      selected: _days.contains(day),
                      onSelected: (v) => setState(() => v ? _days.add(day) : _days.remove(day)),
                      selectedColor: const Color(0xFF2196F3).withOpacity(0.2),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start Time'),
                        subtitle: Text(_start.format(context)),
                        trailing: const Icon(Icons.access_time),
                        onTap: () => _pickTime(true),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('End Time'),
                        subtitle: Text(_end.format(context)),
                        trailing: const Icon(Icons.schedule),
                        onTap: () => _pickTime(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Campus Location (Faculty only)
                if (isFaculty) ...[
                  Text('Campus Location', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<CampusLocationModel>(
                    value: _selectedCampus,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: 'Select campus location',
                    ),
                    items: PredefinedCampuses.campuses.map((campus) {
                      return DropdownMenuItem(
                        value: campus,
                        child: Text(campus.name),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCampus = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _roomController,
                    decoration: InputDecoration(
                      labelText: 'Room Number',
                      prefixIcon: const Icon(Icons.meeting_room),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  TextFormField(
                    controller: _instructor,
                    decoration: const InputDecoration(
                      labelText: 'Instructor',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                TextFormField(
                  controller: _location,
                  decoration: InputDecoration(
                    labelText: isFaculty ? 'Building / Additional Info' : 'Location / Building',
                    prefixIcon: const Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                
                Text('Color', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                BlockPicker(
                  pickerColor: _color,
                  availableColors: AppColors.classPalette,
                  onColorChanged: (c) => setState(() => _color = c),
                ),
                const SizedBox(height: 16),
                
                Text('Alerts', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                SwitchListTile(value: _alert24, onChanged: (v) => setState(() => _alert24 = v), title: const Text('24 hours before')),
                SwitchListTile(value: _alert12, onChanged: (v) => setState(() => _alert12 = v), title: const Text('12 hours before')),
                SwitchListTile(value: _alert2, onChanged: (v) => setState(() => _alert2 = v), title: const Text('2 hours before')),
                SwitchListTile(value: _alert15, onChanged: (v) => setState(() => _alert15 = v), title: const Text('15 minutes before')),
                
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _syncToGoogle,
                  onChanged: (v) => setState(() => _syncToGoogle = v),
                  title: const Text('Add to Google Calendar'),
                ),
                CheckboxListTile(
                  value: _includeAlerts,
                  onChanged: (v) => setState(() => _includeAlerts = v ?? true),
                  title: const Text('Include alerts in Google Calendar'),
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_hasConflict) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Resolve time conflict first')),
                            );
                            return;
                          }
                          if (!_formKey.currentState!.validate()) return;
                          if (user == null) return;
                          
                          // Validate days selection
                          if (_days.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select at least one day')),
                            );
                            return;
                          }
                          
                          final alerts = [
                            if (_alert24) AlertModel(timeBefore: const Duration(hours: 24), isEnabled: true),
                            if (_alert12) AlertModel(timeBefore: const Duration(hours: 12), isEnabled: true),
                            if (_alert2) AlertModel(timeBefore: const Duration(hours: 2), isEnabled: true),
                            if (_alert15) AlertModel(timeBefore: const Duration(minutes: 15), isEnabled: true),
                          ];
                          
                          // Build campus location with room
                          CampusLocationModel? campusWithRoom;
                          if (isFaculty && _selectedCampus != null) {
                            campusWithRoom = CampusLocationModel(
                              name: _selectedCampus!.name,
                              latitude: _selectedCampus!.latitude,
                              longitude: _selectedCampus!.longitude,
                              building: _selectedCampus!.building,
                              room: _roomController.text.isNotEmpty ? _roomController.text : null,
                            );
                          }
                          
                          // Generate invite code for new faculty classes
                          final code = isFaculty 
                              ? (_inviteCode ?? ClassModel.generateInviteCode())
                              : null;
                          
                          final model = ClassModel(
                            id: _editingClass?.id ?? UniqueKey().toString(),
                            userId: user.id,
                            name: _name.text,
                            daysOfWeek: _days.toList(),
                            startTime: _start,
                            endTime: _end,
                            instructorOrRoom: isFaculty ? _roomController.text : _instructor.text,
                            location: _location.text,
                            notes: _notes.text,
                            color: _color,
                            alerts: alerts,
                            syncWithGoogle: _syncToGoogle,
                            isModifiedLocally: true,
                            lastSyncedAt: null,
                            inviteCode: code,
                            facultyId: isFaculty ? user.id : _editingClass?.facultyId,
                            facultyName: isFaculty ? user.fullName : _editingClass?.facultyName,
                            campusLocation: campusWithRoom,
                            enrolledStudentIds: _editingClass?.enrolledStudentIds ?? [],
                          );
                          
                          await classProvider.addOrUpdate(model);
                          if (!mounted) return;
                          
                          // Show invite code dialog for new faculty classes
                          if (isFaculty && !_isEditing && code != null) {
                            _inviteCode = code;
                            await showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => AlertDialog(
                                title: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Text('Class Created!', style: GoogleFonts.poppins(fontSize: 18)),
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
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            code,
                                            style: GoogleFonts.poppins(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 4,
                                              color: const Color(0xFF2196F3),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: const Icon(Icons.copy, color: Color(0xFF2196F3)),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: code));
                                              ScaffoldMessenger.of(ctx).showSnackBar(
                                                const SnackBar(content: Text('Code copied to clipboard')),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Students can use this code to join your class',
                                      style: GoogleFonts.albertSans(fontSize: 12, color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                                actions: [
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Done'),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                        child: Text(_isEditing ? 'Update' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

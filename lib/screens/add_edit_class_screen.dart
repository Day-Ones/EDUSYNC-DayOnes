import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/class.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../services/campus_cache_service.dart';
import '../theme/app_theme.dart';
import 'map_search_screen.dart';

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
  final _cacheService = CampusCacheService();

  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  final Set<int> _days = {1, 3, 5};
  Color _color = AppColors.classPalette.first;
  bool _alertEnabled = true; // Single toggle for alerts
  bool _syncToGoogle = true;
  bool _includeAlerts = true;
  bool _hasConflict = false;

  CampusLocationModel? _selectedCampus;
  List<CampusLocationModel> _recentSearches = [];
  String? _inviteCode;
  ClassModel? _editingClass;
  bool _isEditing = false;
  int _lateGracePeriodMinutes = 10;
  int _absentGracePeriodMinutes = 30;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final recent = await _cacheService.getRecentSearches();
    if (mounted) setState(() => _recentSearches = recent);
  }

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
      _lateGracePeriodMinutes = args.lateGracePeriodMinutes;
      _absentGracePeriodMinutes = args.absentGracePeriodMinutes;
      if (args.campusLocation != null) {
        _selectedCampus = args.campusLocation;
        _roomController.text = args.campusLocation!.room ?? '';
      }
      _alertEnabled =
          args.alerts.isNotEmpty && args.alerts.any((a) => a.isEnabled);
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
        context: context, initialTime: start ? _start : _end);
    if (picked != null) {
      setState(() {
        if (start)
          _start = picked;
        else
          _end = picked;
        _hasConflict = _start.hour > _end.hour ||
            (_start.hour == _end.hour && _start.minute >= _end.minute);
      });
    }
  }

  Future<void> _openMapSearch() async {
    final result = await Navigator.pushNamed(context, MapSearchScreen.routeName)
        as CampusLocationModel?;
    if (result != null) {
      setState(() => _selectedCampus = result);
      await _loadRecentSearches();
    }
  }

  void _showCampusSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 4)
                ],
              ),
              child: Column(
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text('Select Campus',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.map, color: Color(0xFF2196F3)),
                    ),
                    title: Text('Search on Maps',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2196F3))),
                    subtitle: Text('Find any location on the map',
                        style: GoogleFonts.albertSans(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Color(0xFF2196F3)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openMapSearch();
                    },
                  ),
                  const Divider(height: 24),
                  if (PredefinedCampuses.campuses.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Text('Predefined Campuses',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                    ),
                    ...PredefinedCampuses.campuses.map((campus) => ListTile(
                          leading: const Icon(Icons.school,
                              color: Color(0xFF2196F3)),
                          title: Text(campus.name,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              '${campus.latitude.toStringAsFixed(4)}, ${campus.longitude.toStringAsFixed(4)}',
                              style: GoogleFonts.albertSans(
                                  fontSize: 12, color: Colors.grey[600])),
                          onTap: () {
                            setState(() => _selectedCampus = campus);
                            Navigator.pop(ctx);
                          },
                        )),
                  ],
                  if (_recentSearches.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Text('Recent Searches',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                    ),
                    ..._recentSearches
                        .where((r) => !PredefinedCampuses.campuses
                            .any((c) => c.name == r.name))
                        .map((campus) => ListTile(
                              leading:
                                  const Icon(Icons.history, color: Colors.grey),
                              title: Text(campus.name,
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  '${campus.latitude.toStringAsFixed(4)}, ${campus.longitude.toStringAsFixed(4)}',
                                  style: GoogleFonts.albertSans(
                                      fontSize: 12, color: Colors.grey[600])),
                              onTap: () {
                                setState(() => _selectedCampus = campus);
                                Navigator.pop(ctx);
                              },
                            )),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveClass() async {
    final auth = context.read<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final user = auth.user;
    final isFaculty = user?.userType == UserType.faculty;

    if (_hasConflict) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resolve time conflict first')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (user == null) return;
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one day')));
      return;
    }

    final alerts = _alertEnabled
        ? [AlertModel(timeBefore: const Duration(minutes: 15), isEnabled: true)]
        : <AlertModel>[];
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
    final code =
        isFaculty ? (_inviteCode ?? ClassModel.generateInviteCode()) : null;
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
      lateGracePeriodMinutes: _lateGracePeriodMinutes,
      absentGracePeriodMinutes: _absentGracePeriodMinutes,
    );
    await classProvider.addOrUpdate(model);
    if (!mounted) return;
    if (isFaculty && !_isEditing && code != null) {
      _inviteCode = code;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('Class Created!', style: GoogleFonts.poppins(fontSize: 18)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Share this code with your students:',
                style: GoogleFonts.albertSans(color: Colors.grey[600])),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2196F3)),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(code,
                    style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: const Color(0xFF2196F3))),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.copy, color: Color(0xFF2196F3)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Code copied')));
                  },
                ),
              ]),
            ),
          ]),
          actions: [
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Done'))
          ],
        ),
      );
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final user = auth.user;
    final isFaculty = user?.userType == UserType.faculty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _color,
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
          // Check button as shortcut for Save/Update
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: _saveClass,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with class name and time
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: _color.withOpacity(0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name.text.isEmpty
                            ? (_isEditing ? 'Edit Class' : 'New Class')
                            : _name.text,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            '${_start.format(context)} - ${_end.format(context)}',
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
                          Icon(Icons.calendar_today,
                              size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            _formatDays(_days.toList()),
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

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_hasConflict)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Row(children: [
                            Icon(Icons.warning, color: AppColors.warning),
                            SizedBox(width: 8),
                            Expanded(
                                child:
                                    Text('End time must be after start time.'))
                          ]),
                        ),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                            labelText: 'Class Name',
                            prefixIcon: Icon(Icons.class_)),
                        validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Text('Days',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: List.generate(7, (index) {
                          final day = index + 1;
                          const labels = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun'
                          ];
                          return FilterChip(
                            label: Text(labels[index]),
                            selected: _days.contains(day),
                            onSelected: (v) => setState(
                                () => v ? _days.add(day) : _days.remove(day)),
                            selectedColor:
                                const Color(0xFF2196F3).withOpacity(0.2),
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
                                  onTap: () => _pickTime(true))),
                          Expanded(
                              child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('End Time'),
                                  subtitle: Text(_end.format(context)),
                                  trailing: const Icon(Icons.schedule),
                                  onTap: () => _pickTime(false))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isFaculty) ...[
                        Text('Campus',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _showCampusSelector,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: _selectedCampus != null
                                      ? const Color(0xFF2196F3)
                                      : Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(8),
                              color: _selectedCampus != null
                                  ? const Color(0xFF2196F3).withOpacity(0.05)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                    _selectedCampus != null
                                        ? Icons.location_on
                                        : Icons.school,
                                    color: _selectedCampus != null
                                        ? const Color(0xFF2196F3)
                                        : Colors.grey[600]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _selectedCampus != null
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(_selectedCampus!.name,
                                                style: GoogleFonts.poppins(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            Text(
                                                '${_selectedCampus!.latitude.toStringAsFixed(4)}, ${_selectedCampus!.longitude.toStringAsFixed(4)}',
                                                style: GoogleFonts.albertSans(
                                                    fontSize: 12,
                                                    color: Colors.grey[600])),
                                          ],
                                        )
                                      : Text('Select a campus',
                                          style: GoogleFonts.albertSans(
                                              color: Colors.grey[600])),
                                ),
                                if (_selectedCampus != null)
                                  IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () => setState(
                                          () => _selectedCampus = null),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints())
                                else
                                  const Icon(Icons.arrow_drop_down,
                                      color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: _roomController,
                            decoration: InputDecoration(
                                labelText: 'Room Number',
                                prefixIcon: const Icon(Icons.meeting_room),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)))),
                        const SizedBox(height: 16),
                      ] else ...[
                        TextFormField(
                            controller: _instructor,
                            decoration: const InputDecoration(
                                labelText: 'Instructor',
                                prefixIcon: Icon(Icons.person))),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                          controller: _location,
                          decoration: InputDecoration(
                              labelText: isFaculty
                                  ? 'Building / Additional Info'
                                  : 'Location / Building',
                              prefixIcon: const Icon(Icons.business))),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _notes,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Notes',
                              prefixIcon: Icon(Icons.notes),
                              alignLabelWithHint: true)),
                      const SizedBox(height: 16),
                      if (isFaculty) ...[
                        Text('Attendance Grace Periods',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Late Grace Period',
                                            style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                        Text(
                                            'Students can check in late within this period',
                                            style: GoogleFonts.albertSans(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: DropdownButtonFormField<int>(
                                      value: _lateGracePeriodMinutes,
                                      decoration: const InputDecoration(
                                        suffixText: 'min',
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                      ),
                                      items: [5, 10, 15, 20, 30]
                                          .map((mins) => DropdownMenuItem(
                                                value: mins,
                                                child: Text('$mins'),
                                              ))
                                          .toList(),
                                      onChanged: (val) => setState(() =>
                                          _lateGracePeriodMinutes = val ?? 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Absent Grace Period',
                                            style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                        Text(
                                            'After this period, students are marked absent',
                                            style: GoogleFonts.albertSans(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: DropdownButtonFormField<int>(
                                      value: _absentGracePeriodMinutes,
                                      decoration: const InputDecoration(
                                        suffixText: 'min',
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                      ),
                                      items: [15, 20, 30, 45, 60]
                                          .map((mins) => DropdownMenuItem(
                                                value: mins,
                                                child: Text('$mins'),
                                              ))
                                          .toList(),
                                      onChanged: (val) => setState(() =>
                                          _absentGracePeriodMinutes =
                                              val ?? 30),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text('Color',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      BlockPicker(
                          pickerColor: _color,
                          availableColors: AppColors.classPalette,
                          onColorChanged: (c) => setState(() => _color = c)),
                      const SizedBox(height: 16),
                      Text('Alerts',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      SwitchListTile(
                        value: _alertEnabled,
                        onChanged: (v) => setState(() => _alertEnabled = v),
                        title: const Text('Enable Class Reminders'),
                        subtitle: Text(
                          _alertEnabled
                              ? 'You will be notified 15 minutes before class'
                              : 'No reminders',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        secondary: Icon(
                          _alertEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_off,
                          color: _alertEnabled
                              ? const Color(0xFF2196F3)
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                          value: _syncToGoogle,
                          onChanged: (v) => setState(() => _syncToGoogle = v),
                          title: const Text('Add to Google Calendar')),
                      CheckboxListTile(
                          value: _includeAlerts,
                          onChanged: (v) =>
                              setState(() => _includeAlerts = v ?? true),
                          title:
                              const Text('Include alerts in Google Calendar')),
                      const SizedBox(height: 24),
                      _buildSaveButtons(
                          context, classProvider, user, isFaculty),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDays(List<int> days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sortedDays = List<int>.from(days)..sort();
    return sortedDays.map((d) => dayNames[d - 1]).join(', ');
  }

  void _showInviteCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.share, color: Color(0xFF2196F3)),
          const SizedBox(width: 8),
          Text('Class Invite Code', style: GoogleFonts.poppins(fontSize: 18))
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this code with your students:',
                style: GoogleFonts.albertSans(color: Colors.grey[600])),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2196F3))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_inviteCode ?? 'N/A',
                      style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: const Color(0xFF2196F3))),
                  const SizedBox(width: 12),
                  IconButton(
                      icon: const Icon(Icons.copy, color: Color(0xFF2196F3)),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _inviteCode ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied')));
                      }),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                setState(() => _inviteCode = ClassModel.generateInviteCode());
                Navigator.pop(context);
                _showInviteCodeDialog();
              },
              child: const Text('Regenerate')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done')),
        ],
      ),
    );
  }

  Widget _buildSaveButtons(BuildContext context, ClassProvider classProvider,
      UserModel? user, bool isFaculty) {
    return Row(
      children: [
        Expanded(
            child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'))),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveClass,
            child: Text(_isEditing ? 'Update' : 'Save'),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final classProvider = context.read<ClassProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Add / Edit Class')),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Class Name'),
                  validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Text('Days', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    return FilterChip(
                      label: Text(labels[index]),
                      selected: _days.contains(day),
                      onSelected: (v) => setState(() => v ? _days.add(day) : _days.remove(day)),
                    );
                  }),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instructor,
                  decoration: InputDecoration(labelText: user?.userType == UserType.faculty ? 'Room Number' : 'Instructor'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: 'Location / Building'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 12),
                Text('Color', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                BlockPicker(
                  pickerColor: _color,
                  availableColors: AppColors.classPalette,
                  onColorChanged: (c) => setState(() => _color = c),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
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
                          final alerts = [
                            if (_alert24) AlertModel(timeBefore: const Duration(hours: 24), isEnabled: true),
                            if (_alert12) AlertModel(timeBefore: const Duration(hours: 12), isEnabled: true),
                            if (_alert2) AlertModel(timeBefore: const Duration(hours: 2), isEnabled: true),
                            if (_alert15) AlertModel(timeBefore: const Duration(minutes: 15), isEnabled: true),
                          ];
                          final model = ClassModel(
                            id: UniqueKey().toString(),
                            userId: user.id,
                            name: _name.text,
                            daysOfWeek: _days.toList(),
                            startTime: _start,
                            endTime: _end,
                            instructorOrRoom: _instructor.text,
                            location: _location.text,
                            notes: _notes.text,
                            color: _color,
                            alerts: alerts,
                            syncWithGoogle: _syncToGoogle,
                            isModifiedLocally: true,
                            lastSyncedAt: null,
                          );
                          await classProvider.addOrUpdate(model);
                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                        child: const Text('Save'),
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

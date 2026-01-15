import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/reminder_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});
  static const routeName = '/reminder-settings';

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  ReminderSettings _settings = ReminderSettings.defaults();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('reminder_settings_v3');
    if (settingsJson != null) {
      setState(() {
        _settings = ReminderSettings.fromMap(json.decode(settingsJson));
        _isLoading = false;
      });
    } else {
      // First time - use defaults and save them
      _settings = ReminderSettings.defaults();
      await _saveSettings();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminder_settings_v3', json.encode(_settings.toMap()));
  }

  void _toggleClassReminders(bool value) {
    setState(() {
      _settings = _settings.copyWith(classRemindersEnabled: value);
    });
    _saveSettings();
    AppToast.show(
      context,
      message: value ? 'Class reminders enabled' : 'Class reminders disabled',
      type: value ? ToastType.success : ToastType.info,
    );
  }

  void _toggleFacultyEta(bool value) {
    setState(() {
      _settings = _settings.copyWith(facultyEtaEnabled: value);
    });
    _saveSettings();
    AppToast.show(
      context,
      message: value ? 'Faculty ETA notifications enabled' : 'Faculty ETA notifications disabled',
      type: value ? ToastType.success : ToastType.info,
    );
  }

  void _addReminder(ClassReminder reminder) {
    if (!_settings.canAddReminder()) return;
    if (_settings.hasReminder(reminder.minutesBefore)) {
      AppToast.show(context, message: 'This reminder already exists', type: ToastType.warning);
      return;
    }
    
    final updatedReminders = List<ClassReminder>.from(_settings.classReminders)..add(reminder);
    // Sort by minutes (ascending)
    updatedReminders.sort((a, b) => a.minutesBefore.compareTo(b.minutesBefore));
    
    setState(() {
      _settings = _settings.copyWith(classReminders: updatedReminders);
    });
    _saveSettings();
    AppToast.show(context, message: 'Reminder added', type: ToastType.success);
  }

  void _removeReminder(int index) {
    final updatedReminders = List<ClassReminder>.from(_settings.classReminders)..removeAt(index);
    setState(() {
      _settings = _settings.copyWith(classReminders: updatedReminders);
    });
    _saveSettings();
    AppToast.show(context, message: 'Reminder removed', type: ToastType.info);
  }

  void _showAddReminderSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AddReminderSheet(
        existingMinutes: _settings.classReminders.map((r) => r.minutesBefore).toList(),
        onAdd: (reminder) {
          _addReminder(reminder);
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Reminder Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class Reminders Section
                  _buildClassRemindersSection(),
                  const SizedBox(height: 32),

                  // Faculty ETA Section
                  _buildFacultyEtaSection(),
                  const SizedBox(height: 24),

                  // Info Card
                  _buildInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildClassRemindersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with toggle
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _settings.classRemindersEnabled
                  ? [AppColors.primary, AppColors.primary.withOpacity(0.8)]
                  : [Colors.grey[400]!, Colors.grey[500]!],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (_settings.classRemindersEnabled ? AppColors.primary : Colors.grey).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _settings.classRemindersEnabled
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Reminders',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _settings.classRemindersEnabled
                          ? '${_settings.classReminders.length} reminder${_settings.classReminders.length != 1 ? 's' : ''} set'
                          : 'Notifications disabled',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _settings.classRemindersEnabled,
                onChanged: _toggleClassReminders,
                activeColor: Colors.white,
                activeTrackColor: Colors.white.withOpacity(0.4),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.white.withOpacity(0.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Reminder Cards
        if (_settings.classRemindersEnabled) ...[
          // Existing reminder cards
          ...List.generate(_settings.classReminders.length, (index) {
            return _buildReminderCard(index);
          }),

          // Add reminder button (dashed border card) - only show if less than 4 reminders
          if (_settings.canAddReminder()) _buildAddReminderCard(),
        ],
      ],
    );
  }

  Widget _buildReminderCard(int index) {
    final reminder = _settings.classReminders[index];
    
    // Icon and color based on time
    IconData icon;
    Color iconColor;
    if (reminder.minutesBefore >= 60) {
      icon = Icons.hourglass_top_rounded;
      iconColor = Colors.orange;
    } else if (reminder.minutesBefore >= 30) {
      icon = Icons.timer_rounded;
      iconColor = AppColors.warning;
    } else if (reminder.minutesBefore >= 15) {
      icon = Icons.alarm_rounded;
      iconColor = AppColors.primary;
    } else {
      icon = Icons.notifications_rounded;
      iconColor = AppColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                reminder.label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Remove button
            InkWell(
              onTap: () => _removeReminder(index),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddReminderCard() {
    return InkWell(
      onTap: _showAddReminderSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: AppColors.primary.withOpacity(0.5),
            strokeWidth: 1.5,
            dashWidth: 8,
            dashSpace: 5,
            radius: 16,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Add Reminder',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildFacultyEtaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Faculty ETA Notifications',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Get notified about your instructor\'s estimated arrival',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        // Faculty ETA Toggle Card
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _settings.facultyEtaEnabled 
                  ? Colors.teal.withOpacity(0.3) 
                  : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_settings.facultyEtaEnabled ? Colors.teal : Colors.grey).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.directions_walk_rounded,
                        color: _settings.facultyEtaEnabled ? Colors.teal : Colors.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Faculty ETA',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _settings.facultyEtaEnabled 
                                  ? AppColors.textPrimary 
                                  : AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _settings.facultyEtaEnabled 
                                ? 'Notifications at fixed times'
                                : 'Disabled',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _settings.facultyEtaEnabled,
                      onChanged: _toggleFacultyEta,
                      activeColor: Colors.teal,
                    ),
                  ],
                ),
                if (_settings.facultyEtaEnabled) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notification times (fixed):',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildEtaTimeChip('1 hr before'),
                            _buildEtaTimeChip('30 min before'),
                            _buildEtaTimeChip('15 min before'),
                            _buildEtaTimeChip('5 min before'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEtaTimeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.teal[700],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.info, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Reminders',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Class reminders notify you at your chosen times before each class. Faculty ETA notifications are sent at fixed intervals to keep you updated on your instructor\'s arrival.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for dashed border
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 8,
    this.dashSpace = 5,
    this.radius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    path.addRRect(rrect);

    final dashPath = Path();
    final pathMetrics = path.computeMetrics();
    
    for (final metric in pathMetrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashWidth : dashSpace;
        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Helper class to get reminder settings from anywhere
class ReminderSettingsHelper {
  static Future<ReminderSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString('reminder_settings_v3');
    if (settingsJson != null) {
      return ReminderSettings.fromMap(json.decode(settingsJson));
    }
    return ReminderSettings.defaults();
  }

  static Future<void> saveSettings(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminder_settings_v3', json.encode(settings.toMap()));
  }
}

/// Bottom sheet for adding custom reminder time
class _AddReminderSheet extends StatefulWidget {
  final List<int> existingMinutes;
  final Function(ClassReminder) onAdd;

  const _AddReminderSheet({
    required this.existingMinutes,
    required this.onAdd,
  });

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  int _selectedValue = 30;
  String _selectedUnit = 'minutes';
  
  final List<String> _units = ['minutes', 'hours', 'days'];

  int get _totalMinutes {
    switch (_selectedUnit) {
      case 'hours':
        return _selectedValue * 60;
      case 'days':
        return _selectedValue * 1440;
      default:
        return _selectedValue;
    }
  }

  String get _label {
    if (_selectedUnit == 'days') {
      return '$_selectedValue day${_selectedValue > 1 ? 's' : ''} before';
    } else if (_selectedUnit == 'hours') {
      return '$_selectedValue hour${_selectedValue > 1 ? 's' : ''} before';
    } else {
      return '$_selectedValue minute${_selectedValue > 1 ? 's' : ''} before';
    }
  }

  bool get _isDuplicate => widget.existingMinutes.contains(_totalMinutes);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Add Reminder',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set custom time before class',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          // Time picker row
          Row(
            children: [
              // Value input
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '30',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    controller: TextEditingController(text: _selectedValue.toString()),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        setState(() => _selectedValue = parsed);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Unit selector
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedUnit,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      items: _units.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedUnit = value);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDuplicate 
                  ? AppColors.error.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDuplicate 
                    ? AppColors.error.withOpacity(0.3)
                    : AppColors.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isDuplicate ? Icons.error_outline_rounded : Icons.notifications_active_rounded,
                  color: _isDuplicate ? AppColors.error : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isDuplicate ? 'This reminder already exists' : _label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _isDuplicate ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Add button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isDuplicate || _selectedValue <= 0
                  ? null
                  : () {
                      Navigator.pop(context);
                      widget.onAdd(ClassReminder(
                        minutesBefore: _totalMinutes,
                        label: _label,
                      ));
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.border,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Add Reminder',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  bool _alert24 = true;
  bool _alert12 = false;
  bool _alert2 = true;
  bool _alert15 = true;
  bool _syncToGoogle = true;
  bool _includeAlerts = true;
  bool _hasConflict = false;
  
  CampusLocationModel? _selectedCampus;
  List<CampusLocationModel> _recentSearches = [];
  String? _inviteCode;
  ClassModel? _editingClass;
  bool _isEditing = false;

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
      if (args.campusLocation != null) {
        _selectedCampus = args.campusLocation;
        _roomController.text = args.campusLocation!.room ?? '';
      }
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
    final picked = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (picked != null) {
      setState(() {
        if (start) _start = picked; else _end = picked;
        _hasConflict = _start.hour > _end.hour || (_start.hour == _end.hour && _start.minute >= _end.minute);
      });
    }
  }

  Future<void> _openMapSearch() async {
    final result = await Navigator.pushNamed(context, MapSearchScreen.routeName) as CampusLocationModel?;
    if (result != null) {
      setState(() => _selectedCampus = result);
      await _loadRecentSearches();
    }
  }

  void _showCampusSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
              ),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text('Select Campus', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
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
                      decoration: BoxDecoration(color: const Color(0xFF2196F3).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.map, color: Color(0xFF2196F3)),
                    ),
                    title: Text('Search on Maps', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF2196F3))),
                    subtitle: Text('Find any location on the map', style: GoogleFonts.albertSans(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF2196F3)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openMapSearch();
                    },
                  ),
                  const Divider(height: 24),
                  if (PredefinedCampuses.campuses.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Text('Predefined Campuses', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                    ),
                    ...PredefinedCampuses.campuses.map((campus) => ListTile(
                      leading: const Icon(Icons.school, color: Color(0xFF2196F3)),
                      title: Text(campus.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      subtitle: Text('\${campus.latitude.toStringAsFixed(4)}, \${campus.longitude.toStringAsFixed(4)}', style: GoogleFonts.albertSans(fontSize: 12, color: Colors.grey[600])),
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
                      child: Text('Recent Searches', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                    ),
                    ..._recentSearches.where((r) => !PredefinedCampuses.campuses.any((c) => c.name == r.name)).map((campus) => ListTile(
                      leading: const Icon(Icons.history, color: Colors.grey),
                      title: Text(campus.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('\${campus.latitude.toStringAsFixed(4)}, \${campus.longitude.toStringAsFixed(4)}', style: GoogleFonts.albertSans(fontSize: 12, color: Colors.grey[600])),
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

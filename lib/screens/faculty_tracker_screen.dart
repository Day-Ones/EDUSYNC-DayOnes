import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/location.dart';
import '../providers/location_provider.dart';
import '../theme/app_theme.dart';

class FacultyTrackerScreen extends StatefulWidget {
  const FacultyTrackerScreen({super.key});
  static const routeName = '/faculty-tracker';

  @override
  State<FacultyTrackerScreen> createState() => _FacultyTrackerScreenState();
}

class _FacultyTrackerScreenState extends State<FacultyTrackerScreen> {
  String _searchQuery = '';
  String? _selectedDepartment;
  FacultyStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().refreshFacultyLocations();
    });
  }

  List<FacultyLocationModel> _filterFaculty(List<FacultyLocationModel> faculty) {
    return faculty.where((f) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!f.facultyName.toLowerCase().contains(query) &&
            !(f.department?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }
      // Department filter
      if (_selectedDepartment != null && f.department != _selectedDepartment) {
        return false;
      }
      // Status filter
      if (_selectedStatus != null && f.status != _selectedStatus) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> _getDepartments(List<FacultyLocationModel> faculty) {
    return faculty
        .map((f) => f.department)
        .where((d) => d != null)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final allFaculty = locationProvider.facultyLocations;
    final filteredFaculty = _filterFaculty(allFaculty);
    final departments = _getDepartments(allFaculty);

    // Sort by status priority (on campus first)
    filteredFaculty.sort((a, b) => a.status.index.compareTo(b.status.index));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Faculty Tracker',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => locationProvider.refreshFacultyLocations(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search faculty...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Department Filter
                      _buildFilterDropdown(
                        value: _selectedDepartment,
                        hint: 'Department',
                        items: departments,
                        onChanged: (value) => setState(() => _selectedDepartment = value),
                      ),
                      const SizedBox(width: 8),
                      // Status Filter Chips
                      _buildStatusChip(null, 'All'),
                      _buildStatusChip(FacultyStatus.onCampus, 'On Campus'),
                      _buildStatusChip(FacultyStatus.nearby, 'Nearby'),
                      _buildStatusChip(FacultyStatus.enRoute, 'En Route'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Stats Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildStatBadge(
                  allFaculty.where((f) => f.status == FacultyStatus.onCampus).length,
                  'On Campus',
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildStatBadge(
                  allFaculty.where((f) => f.status == FacultyStatus.enRoute).length,
                  'En Route',
                  Colors.orange,
                ),
                const Spacer(),
                Text(
                  '${filteredFaculty.length} faculty',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Faculty List
          Expanded(
            child: filteredFaculty.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => locationProvider.refreshFacultyLocations(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredFaculty.length,
                      itemBuilder: (context, index) {
                        return _buildFacultyCard(filteredFaculty[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 14)),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('All $hint', style: GoogleFonts.inter(fontSize: 14)),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: GoogleFonts.inter(fontSize: 14)),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatusChip(FacultyStatus? status, String label) {
    final isSelected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedStatus = status),
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          color: isSelected ? AppColors.primary : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildStatBadge(int count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No faculty found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyCard(FacultyLocationModel faculty) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showFacultyDetails(faculty),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      faculty.facultyName.split(' ').map((n) => n[0]).take(2).join(),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
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
                        color: faculty.statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      faculty.facultyName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (faculty.department != null)
                      Text(
                        faculty.department!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(faculty.statusIcon, size: 14, color: faculty.statusColor),
                        const SizedBox(width: 4),
                        Text(
                          faculty.statusText,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: faculty.statusColor,
                          ),
                        ),
                        if (faculty.distanceMeters != null && 
                            faculty.status != FacultyStatus.onCampus) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${_formatDistance(faculty.distanceMeters!)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // ETA Badge
              if (faculty.estimatedMinutes != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '~${faculty.estimatedMinutes}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange[700],
                        ),
                      ),
                      Text(
                        'min',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                )
              else if (faculty.status == FacultyStatus.onCampus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green[700],
                    size: 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFacultyDetails(FacultyLocationModel faculty) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      faculty.facultyName.split(' ').map((n) => n[0]).take(2).join(),
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          faculty.facultyName,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (faculty.department != null)
                          Text(
                            faculty.department!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: faculty.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(faculty.statusIcon, color: faculty.statusColor, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            faculty.statusText,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: faculty.statusColor,
                            ),
                          ),
                          if (faculty.lastUpdated != null)
                            Text(
                              'Updated ${_formatTimeAgo(faculty.lastUpdated!)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (faculty.estimatedMinutes != null)
                      Column(
                        children: [
                          Text(
                            '~${faculty.estimatedMinutes}',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: faculty.statusColor,
                            ),
                          ),
                          Text(
                            'minutes',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: faculty.statusColor,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Details
              if (faculty.officeLocation != null) ...[
                _buildDetailRow(Icons.location_on, 'Office', faculty.officeLocation!),
                const SizedBox(height: 12),
              ],
              if (faculty.officeHours != null) ...[
                _buildDetailRow(Icons.access_time, 'Office Hours', faculty.officeHours!),
                const SizedBox(height: 12),
              ],
              if (faculty.distanceMeters != null)
                _buildDetailRow(
                  Icons.straighten,
                  'Distance',
                  _formatDistance(faculty.distanceMeters!),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m away';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km away';
    }
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hr ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }
}

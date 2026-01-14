import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location.dart';
import '../models/user.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  LocationProvider(this._locationService);

  final LocationService _locationService;
  
  bool _isSharing = false;
  bool _hasPermission = false;
  bool _isLoading = false;
  String? _error;
  Position? _currentPosition;
  List<FacultyLocationModel> _facultyLocations = [];
  Timer? _refreshTimer;
  String? _currentUserId;

  bool get isSharing => _isSharing;
  bool get hasPermission => _hasPermission;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Position? get currentPosition => _currentPosition;
  List<FacultyLocationModel> get facultyLocations => _facultyLocations;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> initialize(String userId, UserType userType) async {
    _currentUserId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _hasPermission = await _locationService.checkPermissions();
      
      // Load sharing preference
      final prefs = await SharedPreferences.getInstance();
      _isSharing = prefs.getBool('location_sharing_$userId') ?? false;
      
      // Save faculty info when faculty logs in
      if (userType == UserType.faculty) {
        await _saveFacultyInfo(userId);
      }
      
      if (_isSharing && userType == UserType.faculty) {
        await startSharing();
      }
      
      // For students, start refreshing faculty locations
      if (userType == UserType.student) {
        _startFacultyRefresh();
      }
    } catch (e) {
      _error = 'Failed to initialize location: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save faculty info for later retrieval by students
  Future<void> _saveFacultyInfo(String facultyId) async {
    final prefs = await SharedPreferences.getInstance();
    // Get user info from auth - this would come from the user model in real app
    final existingInfo = prefs.getString('faculty_info_$facultyId');
    if (existingInfo == null) {
      // Will be updated when we have access to user info
      // For now, create placeholder that will be updated
    }
  }

  // Update faculty info (call this after login with user data)
  Future<void> updateFacultyInfo({
    required String facultyId,
    required String name,
    String? department,
    String? officeLocation,
    String? officeHours,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'name': name,
      'department': department,
      'office': officeLocation,
      'hours': officeHours,
      'email': email,
    };
    await prefs.setString('faculty_info_$facultyId', jsonEncode(data));
  }

  Future<bool> requestPermission() async {
    _hasPermission = await _locationService.checkPermissions();
    notifyListeners();
    return _hasPermission;
  }

  // Faculty: Start sharing location
  Future<void> startSharing() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (!_hasPermission) {
        _hasPermission = await requestPermission();
        if (!_hasPermission) {
          _error = 'Location permission denied';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      _isSharing = true;
      
      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_sharing_$_currentUserId', true);
      
      // Start tracking
      await _locationService.startTracking((position) {
        _currentPosition = position;
        _updateFacultyLocation(position);
        notifyListeners();
      });
      
      // Get initial position
      _currentPosition = await _locationService.getCurrentPosition();
      if (_currentPosition != null) {
        _updateFacultyLocation(_currentPosition!);
      }
    } catch (e) {
      _error = 'Failed to start location sharing: $e';
      _isSharing = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Faculty: Stop sharing location
  Future<void> stopSharing() async {
    _isSharing = false;
    _locationService.stopTracking();
    
    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_sharing_$_currentUserId', false);
    
    // Update status to offline
    if (_currentUserId != null) {
      await _saveFacultyStatus(_currentUserId!, FacultyStatus.offline, null, null);
    }
    
    notifyListeners();
  }

  // Toggle sharing
  Future<void> toggleSharing() async {
    if (_isSharing) {
      await stopSharing();
    } else {
      await startSharing();
    }
  }

  void _updateFacultyLocation(Position position) async {
    if (_currentUserId == null) return;
    
    final distance = _locationService.calculateDistance(
      position.latitude,
      position.longitude,
      CampusLocation.schoolLatitude,
      CampusLocation.schoolLongitude,
    );
    
    final status = _locationService.determineStatus(distance);
    final eta = status == FacultyStatus.enRoute || status == FacultyStatus.nearby
        ? _locationService.estimateArrivalMinutes(distance)
        : null;
    
    await _saveFacultyStatus(_currentUserId!, status, distance, eta);
  }

  Future<void> _saveFacultyStatus(
    String facultyId,
    FacultyStatus status,
    double? distance,
    int? eta,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'facultyId': facultyId,
      'status': status.index,
      'distance': distance,
      'eta': eta,
      'timestamp': DateTime.now().toIso8601String(),
      'isSharing': _isSharing,
    };
    await prefs.setString('faculty_location_$facultyId', jsonEncode(data));
  }

  // Student: Refresh faculty locations
  void _startFacultyRefresh() {
    _refreshFacultyLocations();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshFacultyLocations();
    });
  }

  Future<void> _refreshFacultyLocations() async {
    // In a real app, this would fetch from a server
    // For demo, we'll load from local storage and simulate some faculty
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('faculty_location_'));
    
    final locations = <FacultyLocationModel>[];
    
    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final facultyId = data['facultyId'] as String;
        
        // Get faculty info (in real app, from server)
        final facultyInfo = await _getFacultyInfo(facultyId);
        if (facultyInfo != null) {
          locations.add(FacultyLocationModel(
            facultyId: facultyId,
            facultyName: facultyInfo['name'] as String,
            department: facultyInfo['department'] as String?,
            status: FacultyStatus.values[data['status'] as int],
            distanceMeters: data['distance'] as double?,
            estimatedMinutes: data['eta'] as int?,
            lastUpdated: DateTime.tryParse(data['timestamp'] as String),
            isLocationSharing: data['isSharing'] as bool? ?? false,
            officeLocation: facultyInfo['office'] as String?,
            officeHours: facultyInfo['hours'] as String?,
          ));
        }
      }
    }
    
    // Add demo faculty if none exist
    if (locations.isEmpty) {
      locations.addAll(_getDemoFacultyLocations());
    }
    
    _facultyLocations = locations;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _getFacultyInfo(String facultyId) async {
    // In real app, fetch from server/database
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('faculty_info_$facultyId');
    if (raw != null) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    
    // Check if this is a registered faculty user
    final usersRaw = await prefs.getString('auth_users');
    if (usersRaw != null) {
      try {
        final users = jsonDecode(usersRaw) as List<dynamic>;
        for (final user in users) {
          final userMap = user as Map<String, dynamic>;
          if (userMap['id'] == facultyId && userMap['userType'] == 'faculty') {
            return {
              'name': userMap['fullName'] as String,
              'department': userMap['department'] as String?,
              'office': null,
              'hours': null,
              'email': userMap['email'] as String?,
            };
          }
        }
      } catch (_) {}
    }
    
    return null;
  }

  // Demo data for testing
  List<FacultyLocationModel> _getDemoFacultyLocations() {
    final random = Random();
    return [
      FacultyLocationModel(
        facultyId: 'demo-faculty-1',
        facultyName: 'Dr. Maria Santos',
        department: 'Computer Science',
        status: FacultyStatus.onCampus,
        distanceMeters: 150,
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 2)),
        isLocationSharing: true,
        officeLocation: 'Room 301, IT Building',
        officeHours: 'MWF 9:00 AM - 12:00 PM',
      ),
      FacultyLocationModel(
        facultyId: 'demo-faculty-2',
        facultyName: 'Prof. Juan Dela Cruz',
        department: 'Information Technology',
        status: FacultyStatus.enRoute,
        distanceMeters: 3500,
        estimatedMinutes: 12 + random.nextInt(5),
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 1)),
        isLocationSharing: true,
        officeLocation: 'Room 205, Main Building',
        officeHours: 'TTh 1:00 PM - 4:00 PM',
      ),
      FacultyLocationModel(
        facultyId: 'demo-faculty-3',
        facultyName: 'Dr. Ana Reyes',
        department: 'Computer Science',
        status: FacultyStatus.nearby,
        distanceMeters: 800,
        estimatedMinutes: 3,
        lastUpdated: DateTime.now().subtract(const Duration(seconds: 45)),
        isLocationSharing: true,
        officeLocation: 'Room 402, Science Building',
        officeHours: 'MWF 2:00 PM - 5:00 PM',
      ),
      FacultyLocationModel(
        facultyId: 'demo-faculty-4',
        facultyName: 'Prof. Roberto Garcia',
        department: 'Mathematics',
        status: FacultyStatus.away,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
        isLocationSharing: true,
        officeLocation: 'Room 108, Admin Building',
        officeHours: 'TTh 9:00 AM - 11:00 AM',
      ),
      FacultyLocationModel(
        facultyId: 'demo-faculty-5',
        facultyName: 'Dr. Lisa Tan',
        department: 'Information Systems',
        status: FacultyStatus.offline,
        lastUpdated: null,
        isLocationSharing: false,
        officeLocation: 'Room 310, IT Building',
        officeHours: 'MWF 10:00 AM - 1:00 PM',
      ),
    ];
  }

  Future<void> refreshFacultyLocations() async {
    await _refreshFacultyLocations();
  }

  // Call this when user logs out to clean up
  void onLogout() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _locationService.stopTracking();
    _isSharing = false;
    _currentPosition = null;
    _facultyLocations = [];
    _currentUserId = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}

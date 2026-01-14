import 'package:flutter/material.dart';

enum FacultyStatus { onCampus, nearby, enRoute, away, offline }

class LocationModel {
  LocationModel({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isSharing = false,
    this.accuracy,
  });

  final String userId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isSharing;
  final double? accuracy;

  LocationModel copyWith({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    bool? isSharing,
    double? accuracy,
  }) {
    return LocationModel(
      userId: userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      isSharing: isSharing ?? this.isSharing,
      accuracy: accuracy ?? this.accuracy,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
    'isSharing': isSharing,
    'accuracy': accuracy,
  };

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      userId: map['userId'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      isSharing: map['isSharing'] as bool? ?? false,
      accuracy: (map['accuracy'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel.fromMap(json);
}

class FacultyLocationModel {
  FacultyLocationModel({
    required this.facultyId,
    required this.facultyName,
    required this.department,
    required this.status,
    this.distanceMeters,
    this.estimatedMinutes,
    this.lastUpdated,
    this.isLocationSharing = false,
    this.officeLocation,
    this.officeHours,
    this.email,
    this.profileImageUrl,
  });

  final String facultyId;
  final String facultyName;
  final String? department;
  final FacultyStatus status;
  final double? distanceMeters;
  final int? estimatedMinutes;
  final DateTime? lastUpdated;
  final bool isLocationSharing;
  final String? officeLocation;
  final String? officeHours;
  final String? email;
  final String? profileImageUrl;

  String get statusText {
    switch (status) {
      case FacultyStatus.onCampus:
        return 'On Campus';
      case FacultyStatus.nearby:
        return 'Nearby';
      case FacultyStatus.enRoute:
        return estimatedMinutes != null 
            ? 'Arriving in ~$estimatedMinutes min' 
            : 'En Route';
      case FacultyStatus.away:
        return 'Away';
      case FacultyStatus.offline:
        return 'Location Off';
    }
  }

  Color get statusColor {
    switch (status) {
      case FacultyStatus.onCampus:
        return Colors.green;
      case FacultyStatus.nearby:
        return Colors.lightGreen;
      case FacultyStatus.enRoute:
        return Colors.orange;
      case FacultyStatus.away:
        return Colors.red;
      case FacultyStatus.offline:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case FacultyStatus.onCampus:
        return Icons.location_on;
      case FacultyStatus.nearby:
        return Icons.near_me;
      case FacultyStatus.enRoute:
        return Icons.directions_car;
      case FacultyStatus.away:
        return Icons.location_off;
      case FacultyStatus.offline:
        return Icons.signal_wifi_off;
    }
  }

  FacultyLocationModel copyWith({
    String? facultyName,
    String? department,
    FacultyStatus? status,
    double? distanceMeters,
    int? estimatedMinutes,
    DateTime? lastUpdated,
    bool? isLocationSharing,
    String? officeLocation,
    String? officeHours,
    String? email,
    String? profileImageUrl,
  }) {
    return FacultyLocationModel(
      facultyId: facultyId,
      facultyName: facultyName ?? this.facultyName,
      department: department ?? this.department,
      status: status ?? this.status,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isLocationSharing: isLocationSharing ?? this.isLocationSharing,
      officeLocation: officeLocation ?? this.officeLocation,
      officeHours: officeHours ?? this.officeHours,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  Map<String, dynamic> toMap() => {
    'facultyId': facultyId,
    'facultyName': facultyName,
    'department': department,
    'status': status.index,
    'distanceMeters': distanceMeters,
    'estimatedMinutes': estimatedMinutes,
    'lastUpdated': lastUpdated?.toIso8601String(),
    'isLocationSharing': isLocationSharing,
    'officeLocation': officeLocation,
    'officeHours': officeHours,
    'email': email,
    'profileImageUrl': profileImageUrl,
  };

  factory FacultyLocationModel.fromMap(Map<String, dynamic> map) {
    return FacultyLocationModel(
      facultyId: map['facultyId'] as String,
      facultyName: map['facultyName'] as String,
      department: map['department'] as String?,
      status: FacultyStatus.values[map['status'] as int? ?? 4],
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
      estimatedMinutes: map['estimatedMinutes'] as int?,
      lastUpdated: map['lastUpdated'] != null 
          ? DateTime.tryParse(map['lastUpdated'] as String) 
          : null,
      isLocationSharing: map['isLocationSharing'] as bool? ?? false,
      officeLocation: map['officeLocation'] as String?,
      officeHours: map['officeHours'] as String?,
      email: map['email'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory FacultyLocationModel.fromJson(Map<String, dynamic> json) => FacultyLocationModel.fromMap(json);
}

class CampusLocation {
  // Default coordinates (can be configured)
  static double schoolLatitude = 14.5995;
  static double schoolLongitude = 120.9842;
  static double campusRadiusMeters = 500;
  static double nearbyRadiusMeters = 2000;
  static double averageSpeedMps = 8.33;

  static void configure({
    double? latitude,
    double? longitude,
    double? campusRadius,
    double? nearbyRadius,
  }) {
    if (latitude != null) schoolLatitude = latitude;
    if (longitude != null) schoolLongitude = longitude;
    if (campusRadius != null) campusRadiusMeters = campusRadius;
    if (nearbyRadius != null) nearbyRadiusMeters = nearbyRadius;
  }
}

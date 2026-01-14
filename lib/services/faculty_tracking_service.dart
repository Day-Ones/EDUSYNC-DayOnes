import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/class.dart';

class FacultyTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _locationSubscription;
  
  /// Start tracking faculty location and update Firestore
  Future<void> startTracking(String facultyId) async {
    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return;
    }
    
    // Start location updates
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Update every 50 meters
      ),
    ).listen((Position position) {
      _updateFacultyLocation(facultyId, position);
    });
  }
  
  /// Stop tracking
  void stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }
  
  /// Update faculty location in Firestore
  Future<void> _updateFacultyLocation(String facultyId, Position position) async {
    await _firestore.collection('faculty_locations').doc(facultyId).set({
      'facultyId': facultyId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
      'accuracy': position.accuracy,
      'speed': position.speed,
    }, SetOptions(merge: true));
  }
  
  /// Get faculty location stream
  Stream<FacultyLocation?> getFacultyLocationStream(String facultyId) {
    return _firestore
        .collection('faculty_locations')
        .doc(facultyId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      return FacultyLocation(
        facultyId: data['facultyId'] as String,
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        accuracy: (data['accuracy'] as num?)?.toDouble(),
        speed: (data['speed'] as num?)?.toDouble(),
      );
    });
  }
  
  /// Calculate ETA from faculty location to campus
  ETAInfo calculateETA(FacultyLocation facultyLocation, CampusLocationModel campus) {
    final distance = _calculateDistance(
      facultyLocation.latitude,
      facultyLocation.longitude,
      campus.latitude,
      campus.longitude,
    );
    
    // Estimate travel time based on speed or average speed
    double speedKmh = 30.0; // Default average speed in km/h for city traffic
    if (facultyLocation.speed != null && facultyLocation.speed! > 1) {
      speedKmh = facultyLocation.speed! * 3.6; // Convert m/s to km/h
    }
    
    final etaMinutes = (distance / speedKmh) * 60;
    final etaTime = DateTime.now().add(Duration(minutes: etaMinutes.round()));
    
    return ETAInfo(
      distanceKm: distance,
      etaMinutes: etaMinutes.round(),
      estimatedArrival: etaTime,
      facultySpeed: speedKmh,
      lastUpdated: facultyLocation.updatedAt,
    );
  }
  
  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _toRadians(double degrees) => degrees * pi / 180;
}

class FacultyLocation {
  final String facultyId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final double? accuracy;
  final double? speed;
  
  FacultyLocation({
    required this.facultyId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.accuracy,
    this.speed,
  });
}

class ETAInfo {
  final double distanceKm;
  final int etaMinutes;
  final DateTime estimatedArrival;
  final double facultySpeed;
  final DateTime lastUpdated;
  
  ETAInfo({
    required this.distanceKm,
    required this.etaMinutes,
    required this.estimatedArrival,
    required this.facultySpeed,
    required this.lastUpdated,
  });
  
  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
  
  String get formattedETA {
    if (etaMinutes < 1) {
      return 'Arriving';
    } else if (etaMinutes < 60) {
      return '$etaMinutes min';
    } else {
      final hours = etaMinutes ~/ 60;
      final mins = etaMinutes % 60;
      return '${hours}h ${mins}m';
    }
  }
  
  bool get isStale => DateTime.now().difference(lastUpdated).inMinutes > 5;
}

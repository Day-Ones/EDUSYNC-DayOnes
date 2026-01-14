import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  bool _isTracking = false;

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;

  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _currentPosition;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  Future<void> startTracking(Function(Position) onLocationUpdate) async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) return;

    _isTracking = true;
    
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // Update every 50 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _currentPosition = position;
      onLocationUpdate(position);
    });
  }

  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  FacultyStatus determineStatus(double distanceMeters) {
    if (distanceMeters <= CampusLocation.campusRadiusMeters) {
      return FacultyStatus.onCampus;
    } else if (distanceMeters <= CampusLocation.nearbyRadiusMeters) {
      return FacultyStatus.nearby;
    } else if (distanceMeters <= 10000) { // Within 10km
      return FacultyStatus.enRoute;
    } else {
      return FacultyStatus.away;
    }
  }

  int estimateArrivalMinutes(double distanceMeters) {
    // Subtract campus radius since they're "arrived" when on campus
    final effectiveDistance = max(0, distanceMeters - CampusLocation.campusRadiusMeters);
    final seconds = effectiveDistance / CampusLocation.averageSpeedMps;
    return (seconds / 60).ceil();
  }

  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  void dispose() {
    stopTracking();
  }
}

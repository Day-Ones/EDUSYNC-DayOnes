import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/location.dart';
import '../providers/location_provider.dart';
import '../theme/app_theme.dart';

class LocationSettingsScreen extends StatelessWidget {
  const LocationSettingsScreen({super.key});
  static const routeName = '/location-settings';

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    // final auth = context.watch<AuthProvider>();
    final position = locationProvider.currentPosition;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Location Sharing',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Error message if any
          if (locationProvider.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locationProvider.error!,
                      style: GoogleFonts.inter(color: Colors.red[700], fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => locationProvider.clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // Status Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    locationProvider.isSharing 
                        ? Icons.location_on 
                        : Icons.location_off,
                    size: 60,
                    color: locationProvider.isSharing 
                        ? Colors.green 
                        : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    locationProvider.isSharing 
                        ? 'Location Sharing Active' 
                        : 'Location Sharing Off',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    locationProvider.isSharing
                        ? 'Students can see your proximity to campus'
                        : 'Your location is private',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: locationProvider.isLoading 
                          ? null 
                          : () => locationProvider.toggleSharing(),
                      icon: locationProvider.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              locationProvider.isSharing 
                                  ? Icons.location_off 
                                  : Icons.location_on,
                            ),
                      label: Text(
                        locationProvider.isLoading
                            ? 'Please wait...'
                            : locationProvider.isSharing 
                                ? 'Stop Sharing' 
                                : 'Start Sharing',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: locationProvider.isSharing 
                            ? Colors.red 
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Current Location Info
          if (locationProvider.isSharing && position != null) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Status',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusInfo(position),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Permission Status
          if (!locationProvider.hasPermission)
            Card(
              elevation: 2,
              color: Colors.orange[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Permission Required',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[900],
                            ),
                          ),
                          Text(
                            'Enable location access to share your status',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => locationProvider.requestPermission(),
                      child: const Text('Enable'),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Info Section
          Card(
            elevation: 1,
            color: Colors.blue[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    Icons.visibility,
                    'Students see your status',
                    'On Campus, Nearby, En Route, or Away',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoItem(
                    Icons.timer,
                    'Estimated arrival time',
                    'Shown when you\'re en route to campus',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoItem(
                    Icons.security,
                    'Privacy protected',
                    'Exact location is never shared, only proximity',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo(position) {
    final distance = _calculateDistanceToCampus(
      position.latitude,
      position.longitude,
    );
    final status = _determineStatus(distance);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getStatusText(status),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(status),
                ),
              ),
              Text(
                _formatDistance(distance),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blue[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateDistanceToCampus(double lat, double lon) {
    // Simplified distance calculation
    final latDiff = (lat - CampusLocation.schoolLatitude).abs();
    final lonDiff = (lon - CampusLocation.schoolLongitude).abs();
    return (latDiff + lonDiff) * 111000; // Rough meters conversion
  }

  FacultyStatus _determineStatus(double distance) {
    if (distance <= CampusLocation.campusRadiusMeters) {
      return FacultyStatus.onCampus;
    } else if (distance <= CampusLocation.nearbyRadiusMeters) {
      return FacultyStatus.nearby;
    } else if (distance <= 10000) {
      return FacultyStatus.enRoute;
    } else {
      return FacultyStatus.away;
    }
  }

  String _getStatusText(FacultyStatus status) {
    switch (status) {
      case FacultyStatus.onCampus:
        return 'On Campus';
      case FacultyStatus.nearby:
        return 'Nearby';
      case FacultyStatus.enRoute:
        return 'En Route';
      case FacultyStatus.away:
        return 'Away';
      case FacultyStatus.offline:
        return 'Offline';
    }
  }

  Color _getStatusColor(FacultyStatus status) {
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

  IconData _getStatusIcon(FacultyStatus status) {
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

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m from campus';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km from campus';
    }
  }
}

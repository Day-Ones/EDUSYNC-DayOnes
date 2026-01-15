import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/class.dart';
import '../services/campus_search_service.dart';
import '../services/campus_cache_service.dart';
import '../services/connectivity_service.dart';

class MapSearchScreen extends StatefulWidget {
  const MapSearchScreen({super.key});
  static const routeName = '/map-search';

  @override
  State<MapSearchScreen> createState() => _MapSearchScreenState();
}

class _MapSearchScreenState extends State<MapSearchScreen> {
  final MapController _mapController = MapController();
  final _searchController = TextEditingController();
  final _campusSearchService = CampusSearchService();
  final _cacheService = CampusCacheService();

  List<CampusLocationModel> _searchResults = [];
  bool _isSearching = false;
  CampusLocationModel? _selectedLocation;
  Timer? _debounceTimer;
  String? _searchError;
  bool _isOnline = true;

  // Default to PUP Taguig Campus area
  static const LatLng _defaultLocation = LatLng(14.5176, 121.0509);
  LatLng _currentCenter = _defaultLocation;
  double _currentZoom = 14.0;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  void _checkConnectivity() {
    final connectivityService = context.read<ConnectivityService>();
    _isOnline = connectivityService.isOnline;

    if (!_isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOfflineWarning();
      });
    }
  }

  void _showOfflineWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.red),
            const SizedBox(width: 8),
            Text('No Internet Connection', style: GoogleFonts.poppins()),
          ],
        ),
        content: Text(
          'Map features require an internet connection. Please connect to the internet to use this feature.',
          style: GoogleFonts.albertSans(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close map screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (!_isOnline) {
      setState(() {
        _searchError = 'Internet connection required for search';
      });
      return;
    }

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      // Use the Philippine schools search for better results
      final results = await _campusSearchService.searchPhilippineSchools(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
          _searchError = results.isEmpty
              ? 'No results found. Try a different search term.'
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchError =
              'Search failed. Please check your internet connection.';
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();

    if (value.length < 2) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    // Debounce search to avoid too many API calls
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchLocation(value);
    });
  }

  void _selectSearchResult(CampusLocationModel location) {
    setState(() {
      _selectedLocation = location;
      _searchResults = [];
      _searchError = null;
      _searchController.text = location.name;
      _currentCenter = LatLng(location.latitude, location.longitude);
    });

    _mapController.move(LatLng(location.latitude, location.longitude), 16);
    FocusScope.of(context).unfocus();
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    setState(() {
      _selectedLocation = CampusLocationModel(
        name: 'Selected Location',
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _confirmSelection() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location first')),
      );
      return;
    }

    String locationName = _selectedLocation!.name;
    if (locationName == 'Selected Location') {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text('Name this location', style: GoogleFonts.poppins()),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g., PUP Taguig Campus',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (name == null || name.isEmpty) return;
      locationName = name;
    }

    final finalLocation = CampusLocationModel(
      name: locationName,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
    );

    await _cacheService.addRecentSearch(finalLocation);

    if (!mounted) return;
    Navigator.pop(context, finalLocation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
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
      ),
      body: Stack(
        children: [
          // OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: _currentZoom,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dayones.edusync',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_selectedLocation!.latitude,
                          _selectedLocation!.longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin,
                          color: Colors.red, size: 40),
                    ),
                  ],
                ),
            ],
          ),

          // Search Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search PH schools (e.g., TUP, PUP, UST)...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                      _searchError = null;
                                    });
                                  },
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: _searchLocation,
                    textInputAction: TextInputAction.search,
                  ),
                ),

                // Search Results or Error
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (ctx, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.school,
                              color: Color(0xFF2196F3)),
                          title: Text(
                            result.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.albertSans(fontSize: 14),
                          ),
                          dense: true,
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  )
                else if (_searchError != null &&
                    _searchController.text.isNotEmpty &&
                    !_isSearching)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.search_off,
                            color: Colors.grey[400], size: 32),
                        const SizedBox(height: 8),
                        Text(
                          _searchError!,
                          style: GoogleFonts.albertSans(
                              color: Colors.grey[600], fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tip: Try full names like "Technological University of the Philippines" or tap on the map to select manually.',
                          style: GoogleFonts.albertSans(
                              color: Colors.grey[500], fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Zoom Controls
          Positioned(
            right: 16,
            bottom: _selectedLocation != null ? 180 : 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2196F3),
                  onPressed: () {
                    _mapController.move(_mapController.camera.center,
                        _mapController.camera.zoom + 1);
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2196F3),
                  onPressed: () {
                    _mapController.move(_mapController.camera.center,
                        _mapController.camera.zoom - 1);
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // Selected Location Info & Confirm Button
          if (_selectedLocation != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF2196F3)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedLocation!.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                style: GoogleFonts.albertSans(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Select This Location',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

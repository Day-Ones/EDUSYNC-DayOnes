import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/class.dart';

class CampusSearchService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  
  /// Search for schools/universities using OSM Nominatim API
  Future<List<CampusLocationModel>> searchSchools(String query) async {
    return searchPhilippineSchools(query);
  }
  
  /// Search for any location
  Future<List<CampusLocationModel>> searchLocation(String query) async {
    return searchPhilippineSchools(query);
  }
  
  /// Search specifically for educational institutions in Philippines
  Future<List<CampusLocationModel>> searchPhilippineSchools(String query) async {
    if (query.trim().isEmpty) return [];
    
    debugPrint('🔍 Searching for: $query');
    
    // First, check fallback results - return immediately if we have good matches
    final fallbackResults = _getFallbackResults(query);
    if (fallbackResults.isNotEmpty && _isGoodFallbackMatch(query, fallbackResults)) {
      debugPrint('✅ Using local fallback results (${fallbackResults.length} matches)');
      return fallbackResults;
    }
    
    try {
      // Simple direct search
      final searchQuery = '$query Philippines';
      
      final uri = Uri.parse('$_nominatimBaseUrl/search').replace(
        queryParameters: {
          'q': searchQuery,
          'format': 'json',
          'limit': '10',
        },
      );
      
      debugPrint('🌐 API URL: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'EduSync/1.0 (com.dayones.edusync)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));
      
      debugPrint('📡 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('📦 Found ${data.length} results from API');
        
        if (data.isEmpty) {
          // Return fallback if API returns empty
          return fallbackResults.isNotEmpty ? fallbackResults : _getAllFallbackSchools();
        }
        
        final apiResults = _parseResults(data, query);
        // Combine API results with fallback for better coverage
        return _mergeResults(apiResults, fallbackResults);
      } else {
        debugPrint('❌ API error: ${response.statusCode}');
        return fallbackResults.isNotEmpty ? fallbackResults : _getAllFallbackSchools();
      }
    } catch (e) {
      debugPrint('❌ Search error: $e');
      // Return fallback results on any error
      return fallbackResults.isNotEmpty ? fallbackResults : _getAllFallbackSchools();
    }
  }
  
  /// Check if fallback results are a good match for the query
  bool _isGoodFallbackMatch(String query, List<CampusLocationModel> results) {
    final q = query.toLowerCase();
    // Common abbreviations that should use fallback directly
    final directMatches = ['pup', 'tup', 'up', 'dlsu', 'ust', 'feu', 'ue', 'ateneo', 'nu', 'sti', 'ama', 'mapua', 'adamson'];
    return directMatches.any((abbr) => q.contains(abbr)) && results.isNotEmpty;
  }
  
  /// Merge API results with fallback results, removing duplicates
  List<CampusLocationModel> _mergeResults(List<CampusLocationModel> apiResults, List<CampusLocationModel> fallbackResults) {
    final merged = <CampusLocationModel>[...apiResults];
    for (final fallback in fallbackResults) {
      final isDuplicate = merged.any((r) => 
        (r.latitude - fallback.latitude).abs() < 0.01 && 
        (r.longitude - fallback.longitude).abs() < 0.01
      );
      if (!isDuplicate) {
        merged.add(fallback);
      }
    }
    return merged.take(15).toList();
  }
  
  List<CampusLocationModel> _parseResults(List<dynamic> data, String query) {
    return data.map((item) {
      String name = item['name'] as String? ?? 
                   (item['display_name'] as String? ?? query).split(',').first;
      
      if (name.isEmpty) {
        final displayName = item['display_name'] as String? ?? query;
        name = displayName.split(',').first.trim();
      }
      
      // Add city for context
      final displayName = item['display_name'] as String? ?? '';
      final parts = displayName.split(',');
      if (parts.length > 2) {
        final city = parts[2].trim();
        if (!name.toLowerCase().contains(city.toLowerCase())) {
          name = '$name, $city';
        }
      }
      
      debugPrint('  📍 $name');
      
      return CampusLocationModel(
        name: name,
        latitude: double.tryParse(item['lat'].toString()) ?? 0.0,
        longitude: double.tryParse(item['lon'].toString()) ?? 0.0,
      );
    }).toList();
  }
  
  /// Get all fallback schools
  List<CampusLocationModel> _getAllFallbackSchools() {
    return [
      // PUP Campuses
      CampusLocationModel(name: 'Polytechnic University of the Philippines - Main (Sta. Mesa)', latitude: 14.5979, longitude: 121.0109),
      CampusLocationModel(name: 'PUP Taguig Campus', latitude: 14.5176, longitude: 121.0509),
      CampusLocationModel(name: 'PUP San Juan Campus', latitude: 14.6019, longitude: 121.0353),
      CampusLocationModel(name: 'PUP Quezon City Campus', latitude: 14.6280, longitude: 121.0389),
      CampusLocationModel(name: 'PUP Parañaque Campus', latitude: 14.4793, longitude: 121.0198),
      // TUP Campuses
      CampusLocationModel(name: 'Technological University of the Philippines - Manila', latitude: 14.5869, longitude: 120.9846),
      CampusLocationModel(name: 'TUP Taguig Campus', latitude: 14.5131, longitude: 121.0513),
      CampusLocationModel(name: 'TUP Cavite Campus', latitude: 14.4294, longitude: 120.9389),
      // UP Campuses
      CampusLocationModel(name: 'University of the Philippines - Diliman', latitude: 14.6538, longitude: 121.0685),
      CampusLocationModel(name: 'UP Manila', latitude: 14.5794, longitude: 120.9870),
      CampusLocationModel(name: 'UP Los Baños', latitude: 14.1674, longitude: 121.2413),
      // Big 4
      CampusLocationModel(name: 'De La Salle University - Manila', latitude: 14.5648, longitude: 120.9932),
      CampusLocationModel(name: 'Ateneo de Manila University', latitude: 14.6407, longitude: 121.0778),
      CampusLocationModel(name: 'University of Santo Tomas', latitude: 14.6096, longitude: 120.9893),
      // Other Major Universities
      CampusLocationModel(name: 'Far Eastern University - Manila', latitude: 14.6042, longitude: 120.9884),
      CampusLocationModel(name: 'University of the East - Manila', latitude: 14.6019, longitude: 120.9875),
      CampusLocationModel(name: 'Mapua University', latitude: 14.5893, longitude: 120.9847),
      CampusLocationModel(name: 'Adamson University', latitude: 14.5872, longitude: 120.9862),
      CampusLocationModel(name: 'National University - Manila', latitude: 14.6044, longitude: 120.9946),
      CampusLocationModel(name: 'Centro Escolar University', latitude: 14.6033, longitude: 120.9888),
      CampusLocationModel(name: 'San Beda University - Manila', latitude: 14.6028, longitude: 120.9833),
      CampusLocationModel(name: 'Letran College - Manila', latitude: 14.5917, longitude: 120.9778),
      // Tech/IT Schools
      CampusLocationModel(name: 'STI College - Taguig', latitude: 14.5204, longitude: 121.0503),
      CampusLocationModel(name: 'STI College - Makati', latitude: 14.5547, longitude: 121.0244),
      CampusLocationModel(name: 'STI College - Cubao', latitude: 14.6195, longitude: 121.0561),
      CampusLocationModel(name: 'AMA Computer University - Makati', latitude: 14.5512, longitude: 121.0244),
      CampusLocationModel(name: 'AMA Computer University - Quezon City', latitude: 14.6280, longitude: 121.0389),
      CampusLocationModel(name: 'CIIT College of Arts and Technology', latitude: 14.6195, longitude: 121.0561),
      // Taguig Schools
      CampusLocationModel(name: 'Taguig City University', latitude: 14.5204, longitude: 121.0503),
      CampusLocationModel(name: 'University of Makati', latitude: 14.5547, longitude: 121.0244),
    ];
  }
  
  /// Fallback results for common Philippine universities when API fails
  List<CampusLocationModel> _getFallbackResults(String query) {
    final q = query.toLowerCase();
    final fallbackSchools = _getAllFallbackSchools();
    
    // Filter based on query
    final filtered = fallbackSchools.where((school) {
      final schoolName = school.name.toLowerCase();
      
      // Direct name match
      if (schoolName.contains(q)) return true;
      
      // Abbreviation matches
      if (q.contains('pup') && (schoolName.contains('polytechnic') || schoolName.contains('pup'))) return true;
      if (q.contains('tup') && (schoolName.contains('technological university') || schoolName.contains('tup'))) return true;
      if (q.contains('up ') || q == 'up' || q.contains('u.p')) {
        if (schoolName.contains('university of the philippines') || schoolName.startsWith('up ')) return true;
      }
      if (q.contains('dlsu') && schoolName.contains('la salle')) return true;
      if (q.contains('ust') && schoolName.contains('santo tomas')) return true;
      if (q.contains('feu') && schoolName.contains('far eastern')) return true;
      if (q.contains('ue') && schoolName.contains('university of the east')) return true;
      if (q.contains('ateneo') && schoolName.contains('ateneo')) return true;
      if (q.contains('nu') && schoolName.contains('national university')) return true;
      if (q.contains('sti') && schoolName.contains('sti')) return true;
      if (q.contains('ama') && schoolName.contains('ama')) return true;
      if (q.contains('mapua') && schoolName.contains('mapua')) return true;
      if (q.contains('adamson') && schoolName.contains('adamson')) return true;
      if (q.contains('san beda') && schoolName.contains('san beda')) return true;
      if (q.contains('letran') && schoolName.contains('letran')) return true;
      if (q.contains('ceu') && schoolName.contains('centro escolar')) return true;
      
      // Location-based matches
      if (q.contains('taguig') && schoolName.contains('taguig')) return true;
      if (q.contains('makati') && schoolName.contains('makati')) return true;
      if (q.contains('manila') && schoolName.contains('manila')) return true;
      if (q.contains('quezon') && schoolName.contains('quezon')) return true;
      
      // Partial word matches
      final queryWords = q.split(' ');
      for (final word in queryWords) {
        if (word.length >= 3 && schoolName.contains(word)) return true;
      }
      
      return false;
    }).toList();
    
    if (filtered.isNotEmpty) {
      debugPrint('📋 Found ${filtered.length} fallback matches for "$query"');
      return filtered;
    }
    
    return [];
  }
}

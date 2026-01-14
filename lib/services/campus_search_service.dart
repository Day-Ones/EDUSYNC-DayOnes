import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/class.dart';

class CampusSearchService {
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  
  /// Search for schools/universities using OSM Nominatim API
  Future<List<CampusLocationModel>> searchSchools(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final uri = Uri.parse('$_nominatimBaseUrl/search').replace(
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': '10',
          'addressdetails': '1',
        },
      );
      
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'EduSync/1.0 (contact@edusync.app)',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          final address = item['address'] as Map<String, dynamic>?;
          String name = item['display_name'] as String? ?? query;
          
          // Try to get a cleaner name
          if (address != null) {
            name = address['amenity'] as String? ??
                   address['building'] as String? ??
                   address['name'] as String? ??
                   item['name'] as String? ??
                   name.split(',').first;
          }
          
          return CampusLocationModel(
            name: name,
            latitude: double.tryParse(item['lat'].toString()) ?? 0.0,
            longitude: double.tryParse(item['lon'].toString()) ?? 0.0,
            building: address?['building'] as String?,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('OSM search error: $e');
      return [];
    }
  }
  
  /// Search for any location using OSM (for manual search)
  Future<List<CampusLocationModel>> searchLocation(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final uri = Uri.parse('$_nominatimBaseUrl/search').replace(
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': '10',
          'addressdetails': '1',
        },
      );
      
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'EduSync/1.0 (contact@edusync.app)',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          String name = item['display_name'] as String? ?? query;
          // Get shorter name
          final parts = name.split(',');
          if (parts.length > 2) {
            name = '${parts[0]}, ${parts[1]}';
          }
          
          return CampusLocationModel(
            name: name,
            latitude: double.tryParse(item['lat'].toString()) ?? 0.0,
            longitude: double.tryParse(item['lon'].toString()) ?? 0.0,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Location search error: $e');
      return [];
    }
  }
}

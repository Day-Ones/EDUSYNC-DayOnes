import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/class.dart';

class CampusCacheService {
  static const String _recentSearchesKey = 'recent_campus_searches';
  static const int _maxRecentSearches = 5;

  /// Get recent campus searches
  Future<List<CampusLocationModel>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_recentSearchesKey) ?? [];
    
    return jsonList.map((json) {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return CampusLocationModel.fromMap(map);
    }).toList();
  }

  /// Add a campus to recent searches
  Future<void> addRecentSearch(CampusLocationModel campus) async {
    final prefs = await SharedPreferences.getInstance();
    final recentSearches = await getRecentSearches();
    
    // Remove if already exists (to move to top)
    recentSearches.removeWhere((c) => 
      c.name == campus.name && 
      c.latitude == campus.latitude && 
      c.longitude == campus.longitude
    );
    
    // Add to beginning
    recentSearches.insert(0, campus);
    
    // Keep only max items
    if (recentSearches.length > _maxRecentSearches) {
      recentSearches.removeRange(_maxRecentSearches, recentSearches.length);
    }
    
    // Save
    final jsonList = recentSearches.map((c) => jsonEncode(c.toMap())).toList();
    await prefs.setStringList(_recentSearchesKey, jsonList);
  }

  /// Clear all recent searches
  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }
}

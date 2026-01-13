import 'dart:convert';
import 'dart:io';

/// Base API service for backend integration
/// This is a placeholder that should be configured with your actual backend URL
class ApiService {
  ApiService({
    String? baseUrl,
    this.timeout = const Duration(seconds: 30),
  }) : baseUrl = baseUrl ?? 'https://api.example.com/v1';

  final String baseUrl;
  final Duration timeout;
  String? _authToken;

  /// Set the authentication token for API requests
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Get default headers for API requests
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  /// Generic GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
      final client = HttpClient();
      client.connectionTimeout = timeout;
      
      final request = await client.getUrl(uri);
      _headers.forEach((key, value) => request.headers.add(key, value));
      
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      
      return _handleResponse<T>(response.statusCode, body, fromJson);
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Generic POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final client = HttpClient();
      client.connectionTimeout = timeout;
      
      final request = await client.postUrl(uri);
      _headers.forEach((key, value) => request.headers.add(key, value));
      
      if (body != null) {
        request.write(jsonEncode(body));
      }
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      return _handleResponse<T>(response.statusCode, responseBody, fromJson);
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Generic PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final client = HttpClient();
      client.connectionTimeout = timeout;
      
      final request = await client.putUrl(uri);
      _headers.forEach((key, value) => request.headers.add(key, value));
      
      if (body != null) {
        request.write(jsonEncode(body));
      }
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      return _handleResponse<T>(response.statusCode, responseBody, fromJson);
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Generic DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final client = HttpClient();
      client.connectionTimeout = timeout;
      
      final request = await client.deleteUrl(uri);
      _headers.forEach((key, value) => request.headers.add(key, value));
      
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      
      return _handleResponse<T>(response.statusCode, body, fromJson);
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  ApiResponse<T> _handleResponse<T>(
    int statusCode,
    String body,
    T Function(Map<String, dynamic>)? fromJson,
  ) {
    if (statusCode >= 200 && statusCode < 300) {
      if (body.isEmpty) {
        return ApiResponse.success(null);
      }
      
      final json = jsonDecode(body);
      if (fromJson != null && json is Map<String, dynamic>) {
        return ApiResponse.success(fromJson(json));
      }
      return ApiResponse.success(json as T?);
    } else if (statusCode == 401) {
      return ApiResponse.error('Unauthorized. Please login again.');
    } else if (statusCode == 403) {
      return ApiResponse.error('Access denied.');
    } else if (statusCode == 404) {
      return ApiResponse.error('Resource not found.');
    } else if (statusCode >= 500) {
      return ApiResponse.error('Server error. Please try again later.');
    } else {
      try {
        final json = jsonDecode(body);
        final message = json['message'] ?? json['error'] ?? 'Request failed';
        return ApiResponse.error(message);
      } catch (_) {
        return ApiResponse.error('Request failed with status $statusCode');
      }
    }
  }
}

/// API Response wrapper
class ApiResponse<T> {
  ApiResponse._({
    required this.success,
    this.data,
    this.error,
  });

  factory ApiResponse.success(T? data) => ApiResponse._(success: true, data: data);
  factory ApiResponse.error(String message) => ApiResponse._(success: false, error: message);

  final bool success;
  final T? data;
  final String? error;
}

/// API endpoints constants
class ApiEndpoints {
  // Auth
  static const login = '/auth/login';
  static const signup = '/auth/signup';
  static const logout = '/auth/logout';
  static const refreshToken = '/auth/refresh';
  
  // Users
  static const users = '/users';
  static String user(String id) => '/users/$id';
  
  // Classes
  static const classes = '/classes';
  static String classById(String id) => '/classes/$id';
  static String joinClass(String code) => '/classes/join/$code';
  static String leaveClass(String id) => '/classes/$id/leave';
  static String classStudents(String id) => '/classes/$id/students';
  
  // Schedules
  static const schedules = '/schedules';
  static String schedule(String id) => '/schedules/$id';
  
  // Location
  static const facultyLocations = '/locations/faculty';
  static String facultyLocation(String id) => '/locations/faculty/$id';
  static const updateLocation = '/locations/update';
}

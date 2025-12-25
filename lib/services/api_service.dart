import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static String baseUrl = 'https://techmage.in/o/gofast/api';

  /// Fetches client configuration by key (ClientId)
  static Future<Map<String, dynamic>> getClientConfig(String clientId) async {
    try {
      final res = await http
          .get(
            Uri.parse('https://techmage.in/o/gofast/getclientbaseurl/getbykey'),
            headers: {'clientkey': clientId.trim()},
          )
          .timeout(const Duration(seconds: 10));

      return _parseResponse(res);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'error': 'Connection timed out or failed'},
      };
    }
  }

  /// Handles user login
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/Auth'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
      return _parseResponse(res);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'error': 'Login request timed out'},
      };
    }
  }

  /// Fetches regular videos for a specific user
  static Future<Map<String, dynamic>> regularVideos(String email) async {
    try {
      final formattedEmail = email.trim().toUpperCase();
      final res = await http
          .get(
            Uri.parse('$baseUrl/regular_videos'),
            headers: {'useremail': formattedEmail},
          )
          .timeout(const Duration(seconds: 15));
      return _parseVideosResponse(res);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'error': 'Failed to load videos'},
      };
    }
  }

  /// Fetches subscribed videos for a specific user
  static Future<Map<String, dynamic>> subscriptions(String email) async {
    try {
      final formattedEmail = email.trim().toUpperCase();
      final res = await http
          .get(
            Uri.parse('$baseUrl/subscriptions'),
            headers: {'useremail': formattedEmail},
          )
          .timeout(const Duration(seconds: 15));
      return _parseVideosResponse(res);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'error': 'Failed to load library'},
      };
    }
  }

  /// Internal helper to parse general JSON responses
  static Map<String, dynamic> _parseResponse(http.Response res) {
    try {
      final data = jsonDecode(res.body.isEmpty ? '{}' : res.body);
      return {'statusCode': res.statusCode, 'data': data};
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'error': 'Server Error'},
      };
    }
  }

  /// Internal helper specifically for video list responses.
  /// Automatically fixes .html extensions to .m3u8.
  static Map<String, dynamic> _parseVideosResponse(http.Response res) {
    try {
      dynamic data = jsonDecode(res.body.isEmpty ? '{}' : res.body);
      
      List results = [];
      if (data is List) {
        results = data;
      } else if (data is Map && data.containsKey('result')) {
        results = data['result'] as List;
      }

      // Standardize URLs: Replace .html with .m3u8 if found at the end of the URL
      for (var item in results) {
        if (item is Map && item.containsKey('video_url')) {
          String url = item['video_url']?.toString() ?? '';
          if (url.toLowerCase().endsWith('.html')) {
            // Replaces the .html extension with .m3u8
            item['video_url'] = url.replaceAll(RegExp(r'\.html$', caseSensitive: false), '.m3u8');
          }
        }
      }

      return {
        'statusCode': res.statusCode, 
        'data': {'result': results}
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'error': 'Server Error'},
      };
    }
  }
}
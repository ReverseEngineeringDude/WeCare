// ignore_for_file: unused_import

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://techmage.in/o/gofast/api';

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/Auth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseResponse(res);
  }

  static Future<Map<String, dynamic>> regularVideos(String email) async {
    final formattedEmail = email.trim().toUpperCase();
    final res = await http.get(
      Uri.parse('$baseUrl/regular_videos'),
      headers: {'useremail': formattedEmail},
    );
    return _parseVideosResponse(res);
  }

  static Future<Map<String, dynamic>> subscriptions(String email) async {
    final formattedEmail = email.trim().toUpperCase();
    final res = await http.get(
      Uri.parse('$baseUrl/subscriptions'),
      headers: {'useremail': formattedEmail},
    );
    return _parseVideosResponse(res);
  }

  static Map<String, dynamic> _parseResponse(http.Response res) {
    final body = res.body;
    dynamic data;
    try {
      data = jsonDecode(body.isEmpty ? '{}' : body);
    } catch (e) {
      data = {'error': 'Invalid response from server', 'body': body};
    }
    return {'statusCode': res.statusCode, 'data': data};
  }

  static Map<String, dynamic> _parseVideosResponse(http.Response res) {
    final body = res.body;
    dynamic data;
    try {
      data = jsonDecode(body.isEmpty ? '{}' : body);
    } catch (e) {
      data = {'error': 'Invalid response from server', 'body': body};
    }

    if (data is List) {
      data = <String, dynamic>{'result': data};
    }

    return {'statusCode': res.statusCode, 'data': data};
  }
}

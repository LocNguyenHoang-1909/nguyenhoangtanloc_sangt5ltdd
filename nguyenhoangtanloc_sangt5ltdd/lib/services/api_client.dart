import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nguyenhoangtanloc_sangt5ltdd/config/config_url.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? Config_URL.baseUrl;

  Future<http.Response> get(String endpoint, {Map<String, String>? headers}) {
    return http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _buildHeaders(headers),
    );
  }

  Future<http.Response> post(String endpoint, {Map<String, String>? headers, dynamic body}) {
    return http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _buildHeaders(headers),
      body: jsonEncode(body),
    );
  }

  Map<String, String> _buildHeaders(Map<String, String>? headers) {
    return {
      'Content-Type': 'application/json',
      if (headers != null) ...headers,
    };
  }
}
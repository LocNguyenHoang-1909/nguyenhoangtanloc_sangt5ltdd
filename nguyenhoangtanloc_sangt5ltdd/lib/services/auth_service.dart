import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenhoangtanloc_sangt5ltdd/config/config_url.dart';

class AuthService {
  String get apiUrl => "${Config_URL.baseUrl}Authenticate/login";

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        bool status = data['status'];
        if (!status) {
          return {"success": false, "message": data['message']};
        }

        String token = data['token'];
        String role = data['role'] ?? 'User';
        Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('user_role', role);

        return {
          "success": true,
          "token": token,
          "role": role,
          "decodedToken": decodedToken,
        };
      } else {
        return {"success": false, "message": "Đăng nhập thất bại: ${response.statusCode}"};
      }
    } catch (e) {
      return {"success": false, "message": "Lỗi kết nối: $e"};
    }
  }
}
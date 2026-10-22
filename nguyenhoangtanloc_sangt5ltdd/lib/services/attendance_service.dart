import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenhoangtanloc_sangt5ltdd/config/config_url.dart';

class AttendanceService {
  // 1. Admin gọi API tạo mã QR chấm công theo ngày
  static Future<Map<String, dynamic>> generateQrCode() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('${Config_URL.baseUrl}Attendance/generate-qr'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": data['message'] ?? 'Không thể tạo mã QR'};
      }
    } catch (e) {
      return {"success": false, "message": "Lỗi kết nối: $e"};
    }
  }

  // 2. Nhân viên gọi API chấm công (Gửi mã QR và vị trí GPS hiện tại)
  static Future<Map<String, dynamic>> checkIn({
    required String qrToken,
    required String latitude,
    required String longitude,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('${Config_URL.baseUrl}Attendance/check-in'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({
          "qrToken": qrToken,
          "latitude": latitude,
          "longitude": longitude,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {"success": true, "data": data};
      } else {
        return {"success": false, "message": data['message'] ?? 'Chấm công thất bại'};
      }
    } catch (e) {
      return {"success": false, "message": "Lỗi kết nối: $e"};
    }
  }
}
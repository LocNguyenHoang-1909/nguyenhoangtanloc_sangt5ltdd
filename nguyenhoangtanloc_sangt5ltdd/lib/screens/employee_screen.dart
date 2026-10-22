import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenhoangtanloc_sangt5ltdd/config/config_url.dart';
import 'package:nguyenhoangtanloc_sangt5ltdd/screens/login_screen.dart';
import 'package:nguyenhoangtanloc_sangt5ltdd/screens/face_checkin_screen.dart';

class EmployeeScreen extends StatefulWidget {
  final String token; // Token JWT đăng nhập của nhân viên

  const EmployeeScreen({super.key, required this.token});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  bool _isQrUnlocked = false; // Trạng thái mở khóa quét QR sau khi quét mặt thành công
  int _remainingSeconds = 60; // Thời gian hiệu lực quét QR (60 giây)
  Timer? _countdownTimer;

  // Biến lưu trữ thông tin hiển thị trạng thái chấm công trong ngày
  String? _lastCheckInTime;
  String? _lastCheckInStatus;
  String? _lastCheckOutTime;
  String? _lastCheckOutStatus;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Hàm xử lý đăng xuất
  Future<void> _handleLogout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  // Mở màn hình Camera trước quét khuôn mặt bằng Google ML Kit
  void _openFaceVerification() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceCheckInScreen(
          token: widget.token,
          onFaceVerified: () {
            setState(() {
              _isQrUnlocked = true;
              _remainingSeconds = 60;
            });
            _startCountdownTimer();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Xác thực khuôn mặt thành công! Bạn có 1 phút để quét mã QR.'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  // Bộ đếm ngược thời gian mở khóa QR (60 giây)
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isQrUnlocked = false; // Khóa lại sau khi hết thời gian
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hết thời gian quét QR. Vui lòng xác thực lại khuôn mặt!'), backgroundColor: Colors.orange),
        );
      }
    });
  }

  // Hàm xử lý gửi yêu cầu chấm công kèm GPS lên Backend API
  Future<void> _handleCheckIn(String qrToken) async {
    try {
      // 1. Lấy vị trí GPS hiện tại
      Position position = await _determinePosition();

      // 2. Gửi request lên API chấm công Backend
      final url = Uri.parse('${Config_URL.baseUrl}Attendance/check-in');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'qrToken': qrToken,
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Chấm công thành công!'), backgroundColor: Colors.green),
        );

        // Cập nhật trạng thái hiển thị giao diện dựa vào dữ liệu trả về từ API
        setState(() {
          _isQrUnlocked = false; // Khóa lại sau khi chấm công thành công

          if (data['checkInTime'] != null) {
            _lastCheckInTime = data['checkInTime'];
            _lastCheckInStatus = data['attendanceStatus'];
          } else if (data['checkOutTime'] != null) {
            _lastCheckOutTime = data['checkOutTime'];
            _lastCheckOutStatus = data['attendanceStatus'];
          }
        });

        _countdownTimer?.cancel();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chấm công thất bại: ${data['message'] ?? 'Lỗi không xác định'}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi kết nối: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Hàm hỗ trợ lấy vị trí GPS
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Dịch vụ định vị GPS đang bị tắt.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Quyền truy cập vị trí bị từ chối.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Quyền vị trí bị từ chối vĩnh viễn, không thể định vị.';
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang Chấm Công Nhân Viên'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Xác nhận đăng xuất'),
                    content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _handleLogout();
                        },
                        child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.face, size: 70, color: Colors.blueAccent),
            const SizedBox(height: 10),
            const Text(
              'Xác thực khuôn mặt trước khi chấm công',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            const Text(
              'Quét mặt để mở khóa quét mã QR (hiệu lực 60 giây).',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Card hiển thị thông tin chấm công trong ngày (Lần 1 & Lần 2)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Trạng Thái Chấm Công Hôm Nay',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const Divider(),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lần 1 (Đi làm):', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(_lastCheckInTime ?? 'Chưa chấm', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Trạng thái vào:'),
                        Text(
                          _lastCheckInStatus ?? '---',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (_lastCheckInStatus == 'Đi làm đúng giờ') ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lần 2 (Đi về):', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(_lastCheckOutTime ?? 'Chưa chấm', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Trạng thái về:'),
                        Text(
                          _lastCheckOutStatus ?? '---',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (_lastCheckOutStatus == 'Tan làm đúng giờ') ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Nút bấm mở camera trước xác thực khuôn mặt qua ML Kit
            ElevatedButton.icon(
              onPressed: _openFaceVerification,
              icon: const Icon(Icons.camera_front),
              label: const Text('Xác thực khuôn mặt bằng Camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Hiển thị trạng thái mở khóa và Camera quét QR sau khi quét mặt thành công
            if (_isQrUnlocked) ...[
              Text(
                'Thời gian quét QR còn lại: $_remainingSeconds giây',
                style: const TextStyle(fontSize: 15, color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          final String qrToken = barcode.rawValue!;
                          setState(() {
                            _isQrUnlocked = false; // Khóa lại ngay sau khi nhận diện mã
                          });
                          _countdownTimer?.cancel();

                          // Tiến hành gửi yêu cầu chấm công lên API
                          _handleCheckIn(qrToken);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
            ] else ...[
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Camera quét QR đang khóa.\nVui lòng bấm xác thực khuôn mặt phía trên.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
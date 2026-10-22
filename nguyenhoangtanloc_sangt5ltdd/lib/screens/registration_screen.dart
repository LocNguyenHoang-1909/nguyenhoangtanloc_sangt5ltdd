import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:nguyenhoangtanloc_sangt5ltdd/config/config_url.dart';
import 'package:nguyenhoangtanloc_sangt5ltdd/screens/face_capture_screen.dart';
import 'package:nguyenhoangtanloc_sangt5ltdd/screens/otp_verify_screen.dart'; // Import màn hình nhập OTP

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _initialsController = TextEditingController();

  String _selectedRole = 'Employee';
  String? _capturedFaceBase64; // Biến lưu chuỗi ảnh khuôn mặt
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _initialsController.dispose();
    super.dispose();
  }

  // Mở màn hình chụp ảnh khuôn mặt
  Future<void> _openFaceCapture() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FaceCaptureScreen()),
    );

    if (result != null && result is String) {
      setState(() {
        _capturedFaceBase64 = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu dữ liệu khuôn mặt thành công!'), backgroundColor: Colors.green),
      );
    }
  }

  // Gửi thông tin đăng ký lên API để nhận mã OTP qua Gmail
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // RÀNG BUỘC: BẮT BUỘC PHẢI CHỤP ẢNH MẶT MỚI CHO ĐĂNG KÝ
    if (_capturedFaceBase64 == null || _capturedFaceBase64!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chụp ảnh khuôn mặt để hoàn tất đăng ký!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('${Config_URL.baseUrl}Authenticate/register');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'initials': _initialsController.text.trim(),
          'role': _selectedRole,
          'faceImage': _capturedFaceBase64, // Gửi kèm dữ liệu khuôn mặt
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã OTP đã được gửi về Gmail của bạn!'), backgroundColor: Colors.green),
        );

        // Chuyển hướng sang màn hình nhập OTP, truyền kèm email để xác thực
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerifyScreen(email: _emailController.text.trim()),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng ký thất bại: ${data['message'] ?? 'Lỗi không xác định'}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi kết nối server: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng Ký Tài Khoản & Khuôn Mặt'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tạo tài khoản mới',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Tên người dùng', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập tên người dùng' : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập email' : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                validator: (value) => value!.length < 6 ? 'Mật khẩu tối thiểu 6 ký tự' : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _initialsController,
                decoration: const InputDecoration(labelText: 'Mã nhân viên / Initials', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập mã nhân viên' : null,
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Vai trò', border: OutlineInputBorder(), prefixIcon: Icon(Icons.supervised_user_circle)),
                items: const [
                  DropdownMenuItem(value: 'Employee', child: Text('Nhân viên (Employee)')),
                  DropdownMenuItem(value: 'Admin', child: Text('Quản trị viên (Admin)')),
                ],
                onChanged: (value) => setState(() => _selectedRole = value!),
              ),
              const SizedBox(height: 25),

              // Nút chụp ảnh khuôn mặt bắt buộc
              ElevatedButton.icon(
                onPressed: _openFaceCapture,
                icon: Icon(
                  _capturedFaceBase64 != null ? Icons.check_circle : Icons.camera_front,
                  color: Colors.white,
                ),
                label: Text(
                  _capturedFaceBase64 != null ? 'Đã có ảnh khuôn mặt (Bấm chụp lại)' : 'Chụp Ảnh Khuôn Mặt Đăng Ký (*)',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _capturedFaceBase64 != null ? Colors.green : Colors.blueGrey,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 15),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Tiếp Tục (Gửi OTP)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nguyenhoangtanloc_sangt5ltdd/screens/login_screen.dart';

Future<void> main() async {
  // Đảm bảo Flutter binding được khởi tạo trước khi gọi async
  WidgetsFlutterBinding.ensureInitialized();

  // Nạp file cấu hình .env (chứa BASE_URL của Ngrok)
  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Chấm Công - Nguyễn Hoàng Tấn Lộc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Khởi chạy trực tiếp từ màn hình đăng nhập
      home: const LoginScreen(),
    );
  }
}
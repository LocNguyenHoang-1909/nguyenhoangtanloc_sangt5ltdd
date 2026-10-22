import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Thư viện hiển thị mã QR
import 'package:nguyenhoangtanloc_sangt5ltdd/config/config_url.dart';
import 'package:nguyenhoangtanloc_sangt5ltdd/screens/login_screen.dart';

class AdminScreen extends StatefulWidget {
  final String token;
  const AdminScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<dynamic> _attendanceList = [];
  bool _isLoading = true;
  String? _generatedQrToken; // Lưu token mã QR vừa tạo để vẽ lên màn hình
  String _qrMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchAttendanceRecords();
  }

  // 1. Tải danh sách điểm danh từ Server
  Future<void> _fetchAttendanceRecords() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${Config_URL.baseUrl}Attendance/records');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _attendanceList = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: Mã lỗi ${response.statusCode}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể kết nối Server: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 2. Tạo mã QR chấm công trong ngày và lưu lại token để hiển thị
  Future<void> _generateQrCode() async {
    try {
      final url = Uri.parse('${Config_URL.baseUrl}Attendance/generate-qr');
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        setState(() {
          _generatedQrToken = data['qrToken']; // Lấy chuỗi token mã QR từ Server trả về
          _qrMessage = 'Mã QR có hiệu lực đến: ${data['expiresAt']}';
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo mã QR chấm công thành công!'), backgroundColor: Colors.green),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Không thể tạo mã QR'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo QR: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 3. Tải file Excel báo cáo chấm công
  Future<void> _downloadExcel() async {
    final Uri excelUrl = Uri.parse('${Config_URL.baseUrl}Attendance/export-excel');

    if (await launchUrl(excelUrl, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải xuống file Excel điểm danh...'), backgroundColor: Colors.green),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở đường dẫn tải file!'), backgroundColor: Colors.red),
      );
    }
  }

  // 4. Đăng xuất tài khoản
  Future<void> _handleLogout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Trị Viên - Điểm Danh'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hàng chứa nút Tạo mã QR và Tải File Excel nằm cạnh nhau
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateQrCode,
                    icon: const Icon(Icons.qr_code, color: Colors.white),
                    label: const Text('Tạo Mã QR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _downloadExcel,
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Tải File Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            // Nếu đã tạo mã QR thì hiển thị trực tiếp mã QR lên màn hình
            if (_generatedQrToken != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Mã QR Chấm Công Hôm Nay',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 140,
                      width: 140,
                      child: QrImageView(
                        data: _generatedQrToken!,
                        version: QrVersions.auto,
                        gapless: false,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _qrMessage,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Text(
              'Danh sách điểm danh trong ngày:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Vùng hiển thị bảng dữ liệu (DataTable)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _attendanceList.isEmpty
                  ? const Center(
                child: Text(
                  'Chưa có dữ liệu điểm danh trong ngày.',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              )
                  : Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                      columns: const [
                        DataColumn(label: Text('Nhân viên', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Thời gian', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('GPS', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _attendanceList.map((item) {
                        return DataRow(cells: [
                          DataCell(Text(item['userName'] ?? 'N/A')),
                          DataCell(Text(item['checkInTime'] ?? 'N/A')),
                          DataCell(
                            Text(
                              item['status'] ?? 'N/A',
                              style: TextStyle(
                                color: (item['status'].toString().contains('Late') || item['status'].toString().contains('trễ'))
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DataCell(Text('${item['latitude'] ?? ''}, ${item['longitude'] ?? ''}')),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceCheckInScreen extends StatefulWidget {
  final String qrToken; // Nhận mã QR đã quét trước đó nếu cần
  const FaceCheckInScreen({Key? key, required this.qrToken}) : super(key: key);

  @override
  State<FaceCheckInScreen> createState() => _FaceCheckInScreenState();
}

class _FaceCheckInScreenState extends State<FaceCheckInScreen> {
  CameraController? _cameraController;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _faceDetected = false;
  String _statusMessage = 'Đang tìm khuôn mặt... Vui lòng nhìn thẳng vào camera';

  @override
  void initState() {
    super.initState();
    // Khởi tạo ML Kit Face Detector (chế độ nhanh - fast)
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableClassification: true, // Cho phép kiểm tra trạng thái mở/nhắm mắt, cười
      ),
    );
    _initializeCamera();
  }

  // 1. Khởi tạo Camera trước
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    // Chọn camera trước (Front Camera)
    final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {});

    // Bắt đầu lắng nghe luồng khung hình từ camera để xử lý
    _startImageStream();
  }

  // 2. Xử lý luồng hình ảnh qua Google ML Kit
  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        final inputImage = _convertCameraImageToInputImage(image);
        if (inputImage != null) {
          final faces = await _faceDetector.processImage(inputImage);

          if (faces.isNotEmpty) {
            // Đã tìm thấy khuôn mặt
            setState(() {
              _faceDetected = true;
              _statusMessage = 'Đã phát hiện khuôn mặt! Bạn có thể bấm chấm công.';
            });
          } else {
            // Không thấy khuôn mặt trong khung hình
            setState(() {
              _faceDetected = false;
              _statusMessage = 'Không tìm thấy khuôn mặt. Hãy đưa mặt vào giữa khung hình!';
            });
          }
        }
      } catch (e) {
        debugPrint('Lỗi phát hiện khuôn mặt: $e');
      } finally {
        _isDetecting = false;
      }
    });
  }

  // Chuyển đổi khung hình Camera sang định dạng InputImage của ML Kit
  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    // Lấy metadata cơ bản cho hình ảnh
    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw);
    if (inputImageFormat == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg,
        format: inputImageFormat,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // 3. Thực hiện gọi API Chấm công khi khuôn mặt đã được xác thực
  void _performCheckIn() {
    if (!_faceDetected) return;

    // Tắt camera trước khi chuyển trang hoặc gửi request
    _cameraController?.stopImageStream();

    // TODO: Gọi hàm gửi dữ liệu chấm công kèm qrToken lên Backend API của bạn tại đây
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Xác thực khuôn mặt thành công! Đang gửi dữ liệu chấm công...'), backgroundColor: Colors.green),
    );

    // Đóng màn hình quét
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác Thực Khuôn Mặt Chấm Công'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Hiển thị khung hình camera trước
                CameraPreview(_cameraController!),

                // Khung hướng dẫn hình chữ nhật ở giữa màn hình
                Container(
                  width: 250,
                  height: 320,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _faceDetected ? Colors.green : Colors.orange,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _faceDetected ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _faceDetected ? _performCheckIn : null, // Chỉ cho phép bấm khi phát hiện khuôn mặt
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Xác Nhận Chấm Công'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenhoangtanloc_sangt5ltdd/config/config_url.dart';

class FaceCheckInScreen extends StatefulWidget {
  final String token;
  final VoidCallback onFaceVerified; // Callback để báo về EmployeeScreen khi quét mặt thành công

  const FaceCheckInScreen({
    Key? key,
    required this.token,
    required this.onFaceVerified,
  }) : super(key: key);

  @override
  State<FaceCheckInScreen> createState() => _FaceCheckInScreenState();
}

class _FaceCheckInScreenState extends State<FaceCheckInScreen> {
  CameraController? _cameraController;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _faceDetected = false;
  bool _isVerifying = false;
  String _statusMessage = 'Đang tìm khuôn mặt... Hãy nhìn thẳng vào camera trước';

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});
      _startImageStream();
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi khởi động camera: $e';
      });
    }
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isDetecting || _isVerifying) return;
      _isDetecting = true;

      try {
        final inputImage = _convertCameraImageToInputImage(image);
        if (inputImage != null) {
          final faces = await _faceDetector.processImage(inputImage);
          if (faces.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              _faceDetected = true;
              _statusMessage = 'Đã nhận diện khuôn mặt! Bấm xác nhận để so khớp.';
            });
          } else {
            if (!mounted) return;
            setState(() {
              _faceDetected = false;
              _statusMessage = 'Không tìm thấy khuôn mặt. Đưa mặt vào khung hình!';
            });
          }
        }
      } catch (e) {
        debugPrint('Lỗi MLKit: $e');
      } finally {
        _isDetecting = false;
      }
    });
  }

  // Hàm chuyển đổi dữ liệu khung hình chuẩn cho Android & iOS
  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation rotation;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
    } else {
      var rotationCompensation = sensorOrientation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (360 + sensorOrientation) % 360;
      } else {
        rotationCompensation = (sensorOrientation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation) ?? InputImageRotation.rotation270deg;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    // Xử lý gom bytes từ planes
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    // Cấu hình Metadata với ép định dạng NV21 cho Android
    final inputImageMetadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: defaultTargetPlatform == TargetPlatform.android
          ? InputImageFormat.nv21
          : (format ?? InputImageFormat.bgra8888),
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  }

  // Chụp ảnh hiện tại, mã hóa Base64 và gọi API Backend để so sánh với Database
  Future<void> _confirmFace() async {
    if (!_faceDetected || _isVerifying || _cameraController == null) return;

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Đang xác thực khuôn mặt với hệ thống...';
    });

    try {
      await _cameraController?.stopImageStream();

      final XFile picture = await _cameraController!.takePicture();
      final bytes = await picture.readAsBytes();
      final String base64Image = base64Encode(bytes);

      final prefs = await SharedPreferences.getInstance();
      final String? jwtToken = prefs.getString('jwt_token');

      final url = Uri.parse('${Config_URL.baseUrl}Attendance/verify-face');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'currentFaceBase64': base64Image,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Xác thực thành công!'), backgroundColor: Colors.green),
        );

        widget.onFaceVerified();
        Navigator.pop(context);
      } else {
        setState(() {
          _isVerifying = false;
          _statusMessage = data['message'] ?? 'Khuôn mặt không khớp! Vui lòng thử lại.';
        });
        _startImageStream();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _statusMessage = 'Lỗi kết nối xác thực: $e';
      });
      _startImageStream();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác Thực Khuôn Mặt (ML Kit)'),
        backgroundColor: Colors.blueAccent,
      ),
      body: (_cameraController == null || !_cameraController!.value.isInitialized)
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CameraPreview(_cameraController!),
                Container(
                  width: 240,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _faceDetected ? Colors.green : Colors.orange,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                if (_isVerifying)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_faceDetected && !_isVerifying) ? _confirmFace : null,
                    icon: const Icon(Icons.check_circle),
                    label: Text(_isVerifying ? 'Đang xử lý...' : 'Xác Nhận Khuôn Mặt'),
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
import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class RealtimeVerificationScreen extends StatefulWidget {
  const RealtimeVerificationScreen({super.key});

  @override
  State<RealtimeVerificationScreen> createState() => _RealtimeVerificationScreenState();
}

class _RealtimeVerificationScreenState extends State<RealtimeVerificationScreen> {
  late CameraController _cameraController;
  bool _isProcessing = false;
  String _status = "Menginisialisasi kamera...";

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);

    _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
    await _cameraController.initialize();

    if (!mounted) return;
    setState(() {
      _status = "Mendeteksi wajah...";
    });

    // Ambil frame setelah 3 detik
    await Future.delayed(const Duration(seconds: 3));
    _captureAndVerify();
  }

  Future<void> _captureAndVerify() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController.takePicture();
      final refImage = await _getReferensiFile();

      if (refImage == null) {
        setState(() {
          _status = "❗ Wajah referensi tidak ditemukan!";
          _isProcessing = false;
        });
        return;
      }

      final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/compare');
      final request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = 'MASUKKAN_API_KEY_KAMU'
        ..fields['api_secret'] = 'MASUKKAN_API_SECRET_KAMU'
        ..files.add(await http.MultipartFile.fromPath('image_file1', image.path))
        ..files.add(await http.MultipartFile.fromPath('image_file2', refImage.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final json = jsonDecode(responseBody);

      final confidence = json['confidence'] ?? 0;
      if (confidence > 80) {
        setState(() => _status = "✅ Wajah cocok ($confidence)");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SecretScreen()),
        );
      } else {
        setState(() => _status = "❌ Tidak cocok ($confidence)");
      }
    } catch (e) {
      setState(() => _status = "Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<File?> _getReferensiFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/wajah_referensi.png');
    return file.existsSync() ? file : null;
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Verifikasi Wajah Real-Time")),
      body: Stack(
        children: [
          CameraPreview(_cameraController),
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(8),
              child: Text(
                _status,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SecretScreen extends StatelessWidget {
  const SecretScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Area Rahasia")),
      body: const Center(child: Text("🚀 Kamu berhasil masuk real-time!")),
    );
  }
}

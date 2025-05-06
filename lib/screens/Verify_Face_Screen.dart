import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:face_verification_app/realtime_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

late List<CameraDescription> _cameras;

class VerifyFaceScreen extends StatefulWidget {
  const VerifyFaceScreen({super.key});

  @override
  State<VerifyFaceScreen> createState() => _VerifyFaceScreenState();
}

class _VerifyFaceScreenState extends State<VerifyFaceScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isProcessing = false;
  String _status = '';
  Timer? _faceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _faceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(
      _cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.front),
      ResolutionPreset.medium,
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<File?> _getReferensiFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/wajah_referensi.png'); // .png diperbaiki dari .jpg
    return file.existsSync() ? file : null;
  }

  Future<File> _resizeImage(File file, {int maxSizeKB = 500}) async {
    final bytes = await file.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) return file;

    img.Image resized = original;
    int quality = 90;
    List<int> compressed;

    do {
      compressed = img.encodeJpg(resized, quality: quality);
      if (compressed.length / 1024 <= maxSizeKB || quality <= 10) break;
      quality -= 10;
      resized = img.copyResize(original, width: (original.width * 0.9).toInt());
    } while (true);

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/resized_${file.uri.pathSegments.last}');
    await tempFile.writeAsBytes(compressed);
    return tempFile;
  }

  Future<void> _captureAndVerify() async {
    if (_isProcessing || !_controller!.value.isInitialized) return;
    setState(() => _isProcessing = true);

    try {
      final image = await _controller!.takePicture();
      final referensi = await _getReferensiFile();
      if (referensi == null) {
        setState(() {
          _status = "Wajah referensi belum didaftarkan.";
          _isProcessing = false;
        });
        return;
      }

      final resizedImage = await _resizeImage(File(image.path));
      final resizedReferensi = await _resizeImage(referensi);

      final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/compare');
      final request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = 'VXXI6UUl7IghJJmaE_WwuZmOdUxLbohY'
        ..fields['api_secret'] = 'O5jtKlccfktjF_3adrmlUlJtLZCzyC5C'
        ..files.add(await http.MultipartFile.fromPath('image_file1', resizedImage.path))
        ..files.add(await http.MultipartFile.fromPath('image_file2', resizedReferensi.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        final confidence = data['confidence'];
        print("Confidence: $confidence");

        if (confidence > 80) {
          _status = "Wajah cocok! Confidence: $confidence";
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SecretScreen()),
          );
        } else {
          _showFailureDialog("Wajah tidak cocok. Confidence: $confidence");
        }
      } else {
        _showFailureDialog("Gagal verifikasi. Kode: ${response.statusCode}");
      }
    } catch (e) {
      _showFailureDialog("Error saat verifikasi: $e");
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  void _showFailureDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Verifikasi Gagal"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _onFaceInOvalDetected() {
    if (_faceTimer == null || !_faceTimer!.isActive) {
      _faceTimer = Timer(const Duration(seconds: 3), () {
        _captureAndVerify();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verifikasi Wajah"), centerTitle: true,),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: _onFaceInOvalDetected,
              child: Stack(
                children: [
                  CameraPreview(_controller!),
                  Align(
                    alignment: const Alignment(0, -0.3),
                    child: Container(
                      width: 180,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(110),
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                    ),
                  ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  const Positioned(
                    bottom: 120,
                    left: 0,
                    right: 0,
                    child: Text(
                      'Sesuaikan wajah Anda di dalam oval',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ),
                  ),
                  const Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        "Verifikasi otomatis setelah 3 detik",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

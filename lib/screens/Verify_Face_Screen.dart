import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:face_verification_app/screens/secret_screen.dart';
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

class _VerifyFaceScreenState extends State<VerifyFaceScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const String apiKey = 'VXXI6UUl7IghJJmaE_WwuZmOdUxLbohY';
  static const String apiSecret = 'O5jtKlccfktjF_3adrmlUlJtLZCzyC5C';

  CameraController? _controller;
  bool _isProcessing = false;
  String _status = 'Menunggu...';
  Timer? _detectionLoop;
  
  // Variables for liveness detection
  double? _previousYaw;
  bool _hasTurnedHead = false;
  bool _hasBlinked = false;
  int _blinkCount = 0;
  String _instruction = "Silakan gelengkan kepala ke kiri dan kanan";
  List<double> _yawHistory = [];
  bool _isVerifying = false;

  // Animation for scan line
  late AnimationController _animationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: -0.9, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initializeCamera().then((_) {
      _startDetectionLoop();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _detectionLoop?.cancel();
    _animationController.dispose();
    super.dispose();
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

  void _startDetectionLoop() {
    _detectionLoop = Timer.periodic(const Duration(milliseconds: 1000), (_) async {
      if (!mounted || _isProcessing || _controller == null || !_controller!.value.isInitialized || _isVerifying) return;
      
      setState(() => _isProcessing = true);
      
      try {
        final image = await _controller!.takePicture();
        await _analyzeFaceAttributes(File(image.path));
      } catch (e) {
        if (mounted) {
          setState(() => _status = "Error: ${e.toString()}");
        }
      }
      
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  Future<void> _analyzeFaceAttributes(File imageFile) async {
    final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/detect');
    
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['api_secret'] = apiSecret
      ..fields['return_attributes'] = 'headpose,eyestatus'
      ..files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));

    try {
      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        if (data['faces']?.isNotEmpty ?? false) {
          final face = data['faces'][0];
          final attributes = face['attributes'];
          final yawAngle = attributes['headpose']['yaw_angle'].toDouble();
          final leftEyeClosed = attributes['eyestatus']['left_eye_status']['no_glass_eye_close'] > 80;
          final rightEyeClosed = attributes['eyestatus']['right_eye_status']['no_glass_eye_close'] > 80;
          final isBlinking = leftEyeClosed && rightEyeClosed;

          // Update yaw history
          _yawHistory.add(yawAngle);
          if (_yawHistory.length > 10) {
            _yawHistory.removeAt(0);
          }

          // Check for head shaking (left-right movement)
          if (_yawHistory.length >= 5) {
            final maxYaw = _yawHistory.reduce((a, b) => a > b ? a : b);
            final minYaw = _yawHistory.reduce((a, b) => a < b ? a : b);
            
            if ((maxYaw - minYaw) > 20) {
              _hasTurnedHead = true;
              if (mounted) {
                setState(() {
                  _instruction = "Bagus! Sekarang kedipkan mata Anda";
                });
              }
            }
          }

          // Check for blinking
          if (isBlinking) {
            _blinkCount++;
            if (_blinkCount >= 2) {
              _hasBlinked = true;
            }
          }

          // Update UI based on current state
          if (mounted) {
            setState(() {
              if (!_hasTurnedHead) {
                _status = "Deteksi gerakan kepala...";
              } else if (!_hasBlinked) {
                _status = "Deteksi kedipan mata... (${_blinkCount}/2)";
              } else {
                _status = "Verifikasi wajah...";
                _instruction = "Sedang memverifikasi";
              }
            });
          }

          // If both conditions met, start verification
          if (_hasTurnedHead && _hasBlinked && !_isVerifying) {
            _isVerifying = true;
            await _captureAndVerify();
            _isVerifying = false;
          }
        } else {
          if (mounted) {
            setState(() => _status = "Wajah tidak terdeteksi");
          }
        }
      } else {
        if (mounted) {
          setState(() => _status = "Error API: ${response.statusCode} - $responseData");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = "Error: ${e.toString()}");
      }
    }
  }

  Future<bool> _hasFace(File imageFile) async {
    final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/detect');
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['api_secret'] = apiSecret
      ..files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));

    try {
      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        return data['faces']?.isNotEmpty ?? false;
      }
      if (mounted) {
        setState(() => _status = "Error API: ${response.statusCode} - $responseData");
      }
      return false;
    } catch (e) {
      if (mounted) {
        setState(() => _status = "Error: ${e.toString()}");
      }
      return false;
    }
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      final referensi = await _getReferensiFile();
      if (referensi == null) {
        if (mounted) {
          setState(() {
            _status = "Wajah referensi belum ada.";
          });
        }
        return;
      }

      // Validasi wajah di kedua gambar
      final hasFaceInCamera = await _hasFace(File(image.path));
      final hasFaceInReference = await _hasFace(referensi);

      if (!hasFaceInCamera || !hasFaceInReference) {
        if (mounted) {
          setState(() {
            _status = "Wajah tidak terdeteksi di salah satu gambar.";
            _instruction = "Pastikan wajah terlihat jelas.";
          });
          _hasTurnedHead = false;
          _hasBlinked = false;
          _blinkCount = 0;
          _yawHistory.clear();
        }
        return;
      }

      final resizedImage = await _resizeImage(File(image.path));
      final resizedReferensi = await _resizeImage(referensi);

      final uri = Uri.parse('https://api-us.faceplusplus.com/facepp/v3/compare');
      final request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = apiKey
        ..fields['api_secret'] = apiSecret
        ..files.add(await http.MultipartFile.fromPath('image_file1', resizedImage.path))
        ..files.add(await http.MultipartFile.fromPath('image_file2', resizedReferensi.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        final confidence = data['confidence'] ?? 0;

        if (mounted) {
          if (confidence > 80) {
            setState(() {
              _status = "Verifikasi berhasil (${confidence.toStringAsFixed(1)}%)";
              _instruction = "Berhasil!";
            });
            await Future.delayed(const Duration(seconds: 1));
            if (!mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SecretScreen()));
          } else {
            setState(() {
              _status = "Verifikasi gagal (${confidence.toStringAsFixed(1)}%)";
              _instruction = "Silakan coba lagi";
            });
            _hasTurnedHead = false;
            _hasBlinked = false;
            _blinkCount = 0;
            _yawHistory.clear();
          }
        }
      } else {
        if (mounted) {
          setState(() => _status = "Error API: ${response.statusCode} - $responseData");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = "Error: ${e.toString()}");
      }
    }
  }

  Future<File?> _getReferensiFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/wajah_referensi.png');
    if (!file.existsSync()) {
      return null;
    }
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        return null;
      }
    } catch (e) {
      return null;
    }
    return file;
  }

  Future<File> _resizeImage(File file, {int maxSizeKB = 500}) async {
    final bytes = await file.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) return file;

    img.Image resized = img.copyResize(original, width: 600);
    int quality = 85;
    List<int> compressed = img.encodeJpg(resized, quality: quality);

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/resized_${file.uri.pathSegments.last}');
    await tempFile.writeAsBytes(compressed);

    final fileSizeKB = (await tempFile.length()) ~/ 1024;
    if (fileSizeKB > 2000) {
      throw Exception("Ukuran gambar terlalu besar setelah resize: ${fileSizeKB}KB");
    }

    return tempFile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 79, 79, 79),
      appBar: AppBar(title: const Text("Verifikasi Wajah"), centerTitle: true),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CameraPreview(_controller!),
                Align(
                  alignment: const Alignment(0, -0.3),
                  child: ClipOval(
                    child: Container(
                      width: 180,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        _instruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isProcessing || _isVerifying)
                  Align(
                    alignment: const Alignment(0, -0.3),
                    child: ClipOval(
                      child: Container(
                        width: 180,
                        height: 250,
                        child: AnimatedBuilder(
                          animation: _scanAnimation,
                          builder: (context, child) {
                            return Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: (250 * (_scanAnimation.value + 0.9) / 1.8),
                                  child: Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
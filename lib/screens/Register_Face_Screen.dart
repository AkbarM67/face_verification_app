import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

late List<CameraDescription> _cameras;

class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({super.key});

  @override
  State<RegisterFaceScreen> createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen> {
  static const String apiKey = 'VXXI6UUl7IghJJmaE_WwuZmOdUxLbohY';
  static const String apiSecret = 'O5jtKlccfktjF_3adrmlUlJtLZCzyC5C';

  CameraController? _controller;
  bool _isSaving = false;
  String _message = 'Arahkan wajah ke dalam bingkai dan tekan tombol simpan.';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(
      _cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front),
      ResolutionPreset.medium, // Sama dengan VerifyFaceScreen
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
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
        setState(() => _message = "Error API: ${response.statusCode} - $responseData");
      }
      return false;
    } catch (e) {
      if (mounted) {
        setState(() => _message = "Error: ${e.toString()}");
      }
      return false;
    }
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

  Future<void> _saveReferenceFace() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isSaving = true);

    try {
      final picture = await _controller!.takePicture();
      final imageFile = File(picture.path);

      // Validasi apakah gambar berisi wajah
      final hasFace = await _hasFace(imageFile);
      if (!hasFace) {
        setState(() {
          _message = "Wajah tidak terdeteksi. Pastikan wajah terlihat jelas.";
        });
        setState(() => _isSaving = false);
        return;
      }

      // Resize gambar untuk konsistensi dengan verifikasi
      final resizedImage = await _resizeImage(imageFile);

      // Simpan gambar
      final appDir = await getApplicationDocumentsDirectory();
      final savedFile = File('${appDir.path}/wajah_referensi.png');
      await resizedImage.copy(savedFile.path);

      setState(() {
        _message = "Wajah referensi berhasil disimpan";
      });
    } catch (e) {
      setState(() {
        _message = "Gagal menyimpan wajah: $e";
      });
    }

    setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sama dengan VerifyFaceScreen
      appBar: AppBar(title: const Text("Daftarkan Wajah"), centerTitle: true),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CameraPreview(_controller!),
                Align(
                  alignment: const Alignment(0, -0.3),
                  child: ClipOval(
                    child: Container(
                      width: 300,
                      height: 350,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 140,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_isSaving)
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      if (!_isSaving)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: _saveReferenceFace,
                          icon: const Icon(Icons.save),
                          label: const Text("Simpan Wajah"),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
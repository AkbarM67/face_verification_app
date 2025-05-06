import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({super.key});

  @override
  State<RegisterFaceScreen> createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen> {
  File? _capturedImage;
  final picker = ImagePicker();
  String _status = '';

  Future<void> _captureFace() async {
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final fileSizeKB = file.lengthSync() / 1024;

      final resizedFile = fileSizeKB > 3000
          ? await _saveTempFile(await _resizeImage(file))
          : file;

      setState(() => _capturedImage = resizedFile);
    } catch (e) {
      setState(() => _status = "Terjadi kesalahan saat mengambil gambar.");
    }
  }

  Future<Uint8List> _resizeImage(File file) async {
    final imageBytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(imageBytes, targetWidth: 300);
    final frame = await codec.getNextFrame();
    final resized = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return resized!.buffer.asUint8List();
  }

  Future<File> _saveTempFile(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/temp_face.png');
    return await file.writeAsBytes(bytes);
  }

  Future<void> _saveImage() async {
    if (_capturedImage == null) return;
    final appDir = await getApplicationDocumentsDirectory();
    final savedImage = await _capturedImage!.copy('${appDir.path}/wajah_referensi.png');

    setState(() {
      _capturedImage = savedImage;
      _status = 'Wajah berhasil disimpan sebagai referensi';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wajah berhasil disimpan sebagai referensi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftarkan Wajah"), centerTitle: true,),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _capturedImage != null
                ? Image.file(_capturedImage!, width: 200)
                : const Text("Belum ada wajah tersimpan"),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero, 
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
              ),
              onPressed: _captureFace,
              child: const Text("Ambil Foto Wajah"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero, 
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
              ),
              onPressed: _saveImage,
              child: const Text("Simpan Wajah"),
            ),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

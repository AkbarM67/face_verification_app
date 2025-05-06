import 'package:flutter/material.dart';
import 'package:face_verification_app/screens/register_face_screen.dart';
import 'package:face_verification_app/screens/verify_face_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Home"), centerTitle: true,),
      
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero, 
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterFaceScreen()),
              ),
              child: const Text("Daftarkan Wajah",),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VerifyFaceScreen()),
              ),
              child: const Text("Masuk Area Rahasia"),
            ),
          ],
        ),
      ),
    );
  }
}

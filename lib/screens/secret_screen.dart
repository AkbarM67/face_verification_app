import 'package:flutter/material.dart';

class SecretScreen extends StatelessWidget {
  const SecretScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Area Rahasia")),
      body: const Center(
        child: Text("🚀 Selamat datang di area rahasia"),
      ),
    );
  }
}

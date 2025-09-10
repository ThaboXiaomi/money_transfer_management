import 'package:flutter/material.dart';

class KYCScreen extends StatelessWidget {
  const KYCScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KYC')),
      body: const Center(child: Text('KYC verification and documents')),
    );
  }
}

import 'package:flutter/material.dart';

class SenderProfileScreen extends StatelessWidget {
  const SenderProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sender Profile')),
      body: const Center(child: Text('Customer profile and history')),
    );
  }
}

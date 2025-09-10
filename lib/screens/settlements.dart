import 'package:flutter/material.dart';

class SettlementsScreen extends StatelessWidget {
  const SettlementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settlements')),
      body: const Center(child: Text('Settlement batches and reconciliation')),
    );
  }
}

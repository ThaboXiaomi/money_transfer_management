import 'package:flutter/material.dart';

class TransferDetailScreen extends StatelessWidget {
  const TransferDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer Detail')),
      body: const Center(child: Text('Transfer detail and actions')),
    );
  }
}

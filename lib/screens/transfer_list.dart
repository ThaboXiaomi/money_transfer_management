import 'package:flutter/material.dart';

class TransferListScreen extends StatelessWidget {
  const TransferListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfers')),
      body: const Center(child: Text('List of transfers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/create-transfer'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

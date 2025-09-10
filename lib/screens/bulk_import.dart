import 'package:flutter/material.dart';

class BulkImportScreen extends StatelessWidget {
  const BulkImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Import')),
      body: const Center(child: Text('CSV upload and import jobs')),
    );
  }
}

import 'package:flutter/material.dart';

class CreateTransferScreen extends StatelessWidget {
  const CreateTransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Transfer')),
      body: const Center(child: Text('Form to create a transfer')),
    );
  }
}

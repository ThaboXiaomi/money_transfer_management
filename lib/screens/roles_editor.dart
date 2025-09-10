import 'package:flutter/material.dart';

class RolesEditorScreen extends StatelessWidget {
  const RolesEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roles')),
      body: const Center(child: Text('Edit roles & permissions')),
    );
  }
}

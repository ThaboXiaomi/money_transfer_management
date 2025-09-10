import 'package:flutter/material.dart';

class PricingEditorScreen extends StatelessWidget {
  const PricingEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pricing Editor')),
      body: const Center(child: Text('Manage fee rules')),
    );
  }
}

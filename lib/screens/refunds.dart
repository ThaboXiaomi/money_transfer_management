import 'package:flutter/material.dart';

class RefundsScreen extends StatelessWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refunds')),
      body: const Center(child: Text('Manage refunds and chargebacks')),
    );
  }
}

import 'package:flutter/material.dart';

class AgentDashboardScreen extends StatelessWidget {
  const AgentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Dashboard')),
      body: const Center(child: Text('Agent queue and stats')),
    );
  }
}

import 'package:flutter/material.dart';

class AgentLocatorScreen extends StatelessWidget {
  const AgentLocatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Locator')),
      body: const Center(child: Text('Map of nearby agents')),
    );
  }
}

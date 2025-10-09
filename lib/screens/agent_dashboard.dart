import 'package:flutter/material.dart';
import '../services/app_init.dart';

class AgentDashboardScreen extends StatelessWidget {
  const AgentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
              await AppInit.logout();
              if (!Navigator.of(context).mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/role-selection',
                (r) => false,
              );
            },
          ),
        ],
      ),
      body: const Center(child: Text('Agent queue and stats')),
    );
  }
}

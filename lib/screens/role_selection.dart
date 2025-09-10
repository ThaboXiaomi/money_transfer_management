import 'package:flutter/material.dart';
import 'agent_screen.dart';
import 'admin_screen.dart';
import '../services/config.dart';
import 'login.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giant Money Transfer')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo.jpg',
                  height: 100,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text(
                  'Fast, secure transfers between SA and Lesotho',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (AppConfig.useBackend) {
                          final ok = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const LoginScreen(nextRole: 'agent'),
                            ),
                          );
                          if (ok == true)
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AgentScreen(),
                              ),
                            );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AgentScreen(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_search),
                      label: const Text('Agent'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (AppConfig.useBackend) {
                          final ok = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const LoginScreen(nextRole: 'admin'),
                            ),
                          );
                          if (ok == true)
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminScreen(),
                              ),
                            );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminScreen(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Admin'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

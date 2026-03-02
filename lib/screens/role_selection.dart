import 'package:flutter/material.dart';
import 'agent_screen.dart';
import 'admin_screen.dart';
import '../services/config.dart';
import 'login.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shown) {
      _shown = true;
      // show the backend URL for debugging
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = context;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Backend -> ${AppConfig.backendBase}')),
        );
      });
    }
  }

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
                const SizedBox(height: 16),
                // quick links to scaffolded screens for development/testing
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/dashboard'),
                      child: const Text('Dashboard'),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/transfers'),
                      child: const Text('Transfers'),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/recipients'),
                      child: const Text('Recipients'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/pricing'),
                      child: const Text('Pricing'),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/exchange-rates'),
                      child: const Text('Rates'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/users'),
                      child: const Text('Users'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/support'),
                      child: const Text('Support'),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/feature-roadmap'),
                      child: const Text('150 Features'),
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

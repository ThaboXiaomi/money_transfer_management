import 'dart:io';

import 'package:flutter/material.dart';
import '../services/local_db.dart';
import '../services/config.dart';
import '../services/api_service.dart';
import '../models/transfer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Transfer>> _transfers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _transfers = AppConfig.useBackend
        ? ApiService.fetchTransfers()
        : LocalDb.instance.readAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder<List<Transfer>>(
        future: _transfers,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final list = snap.data ?? <Transfer>[];
          final total = list.fold<double>(0, (p, e) => p + e.amount);
          final count = list.length;
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _cardStat(
                        'Transfers',
                        count.toString(),
                        Icons.swap_horiz,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _cardStat(
                        'Total',
                        AppConfig.formatCurrency(total),
                        Icons.attach_money,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text('No activity yet'))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final t = list[i];
                            return ListTile(
                              leading: t.screenshotPath.isNotEmpty
                                  ? (AppConfig.useBackend
                                        ? Image.network(
                                            t.screenshotPath,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(t.screenshotPath),
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                          ))
                                  : const CircleAvatar(
                                      child: Icon(Icons.receipt_long),
                                    ),
                              title: Text(
                                '${t.agentName} — ${AppConfig.formatCurrency(t.amount)}',
                              ),
                              subtitle: Text(
                                'To: ${t.receiverNumber} • ${t.status}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cardStat(String title, String value, IconData icon) => Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Colors.indigo),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ],
      ),
    ),
  );
}

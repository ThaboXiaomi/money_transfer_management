import 'dart:io';
import 'package:flutter/material.dart';
import '../models/transfer.dart';
import '../services/local_db.dart';
import '../services/config.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<Transfer>> _transfers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (AppConfig.useBackend) {
      _transfers = ApiService.fetchTransfers();
    } else {
      _transfers = LocalDb.instance.readAll();
    }
  }

  Future<void> _exportCsv() async {
    if (AppConfig.useBackend) {
      final uri = Uri.parse('${AppConfig.backendBase}/transfers/export/csv');
      final prefs = await http.get(uri);
      if (prefs.statusCode == 200) {
        final bytes = prefs.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/transfers_${DateTime.now().millisecondsSinceEpoch}.csv',
        );
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV saved to ${file.path}')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${prefs.statusCode}')),
        );
      }
    } else {
      final list = await LocalDb.instance.readAll();
      final rows = <List<dynamic>>[];
      rows.add([
        'id',
        'agentName',
        'senderNumber',
        'receiverNumber',
        'amount',
        'charge',
        'agentFee',
        'screenshotPath',
        'status',
      ]);
      for (final t in list) {
        rows.add([
          t.id,
          t.agentName,
          t.senderNumber,
          t.receiverNumber,
          t.amount,
          t.charge,
          t.agentFee,
          t.screenshotPath,
          t.status,
        ]);
      }
      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/transfers_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV saved to ${file.path}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(onPressed: _exportCsv, icon: const Icon(Icons.download)),
        ],
      ),
      body: FutureBuilder<List<Transfer>>(
        future: _transfers,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text('No transfers yet'));
          }
          final list = snap.data!;
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final t = list[i];
              final leading = t.screenshotPath.isNotEmpty
                  ? (AppConfig.useBackend
                        ? Image.network(
                            t.screenshotPath,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(t.screenshotPath),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ))
                  : const Icon(Icons.receipt_long, size: 56);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: leading,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${t.agentName} — ${t.amount.toStringAsFixed(2)} R',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Receiver: ${t.receiverNumber}'),
                            if (((t as dynamic).txRef ?? '').isNotEmpty)
                              Text('TX Ref: ${(t as dynamic).txRef}'),
                            Text(
                              'Agent fee: ${t.agentFee.toStringAsFixed(2)} R',
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              final ctrl = TextEditingController();
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Mark as sent'),
                                  content: TextField(
                                    controller: ctrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Transaction reference',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Mark'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                final tx = ctrl.text.trim();
                                if (AppConfig.useBackend) {
                                  final id = t.id; // id expected
                                  final uri = Uri.parse(
                                    '${AppConfig.backendBase}/transfers/$id/mark_sent',
                                  );
                                  final prefs = await http.post(
                                    uri,
                                    body: {'txRef': tx},
                                  );
                                  if (prefs.statusCode == 200) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Marked sent'),
                                      ),
                                    );
                                    setState(() => _load());
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed: ${prefs.statusCode}',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  final db = await LocalDb.instance.database;
                                  await db.update(
                                    'transfers',
                                    {'status': 'sent', 'txRef': tx},
                                    where: 'id = ?',
                                    whereArgs: [t.id],
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Marked sent locally'),
                                    ),
                                  );
                                  setState(() => _load());
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

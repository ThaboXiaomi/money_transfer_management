// don't import dart:io directly; use platform helpers for file ops
import 'package:flutter/material.dart';
import '../models/transfer.dart';
import '../services/local_db.dart';
import '../services/config.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../services/platform_file.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Transfer>> _transfers;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV ready (web): saved on server')),
          );
        } else {
          final dir = await getTemporaryDirectory();
          final filename =
              'transfers_${DateTime.now().millisecondsSinceEpoch}.csv';
          final path = pf_writeFileBytesSync(dir.path, filename, bytes);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('CSV saved to $path')));
        }
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
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV ready (web): copy from UI')),
        );
      } else {
        final dir = await getTemporaryDirectory();
        final filename =
            'transfers_${DateTime.now().millisecondsSinceEpoch}.csv';
        final path = pf_writeFileStringSync(dir.path, filename, csv);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV saved to $path')));
      }
    }
  }

  Widget _buildSummary(List<Transfer> list) {
    final total = list.fold<double>(0, (p, e) => p + e.amount);
    final count = list.length;
    final pending = list.where((t) => t.status == 'pending').length;
    final sent = list.where((t) => t.status == 'sent').length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statTile(
              'Total transferred',
              AppConfig.formatCurrency(total),
              Icons.attach_money,
            ),
            _statTile('Transfers', count.toString(), Icons.swap_horiz),
            _statTile('Pending', pending.toString(), Icons.hourglass_empty),

            _statTile('Sent', sent.toString(), Icons.send),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String title, String value, IconData icon) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 28, color: Colors.indigo),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(title, style: const TextStyle(color: Colors.black54)),
    ],
  );

  Widget _transfersTab() {
    return FutureBuilder<List<Transfer>>(
      future: _transfers,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.isEmpty) {
          return const Center(child: Text('No transfers yet'));
        }
        final list = snap.data!;
        return Column(
          children: [
            _buildSummary(list),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final t = list[i];
                  Widget leading = const Icon(Icons.receipt_long, size: 56);
                  if (t.screenshotPath.isNotEmpty) {
                    try {
                      final src = t.screenshotPath.trim();
                      if (src.startsWith('data:image')) {
                        // base64 data URI
                        leading = Image.memory(
                          UriData.parse(src).contentAsBytes(),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        );
                      } else if (AppConfig.useBackend &&
                          (src.startsWith('http://') ||
                              src.startsWith('https://'))) {
                        // Only attempt network image decoding for known image file extensions.
                        final lower = src.toLowerCase();
                        final isImage =
                            lower.endsWith('.png') ||
                            lower.endsWith('.jpg') ||
                            lower.endsWith('.jpeg') ||
                            lower.endsWith('.gif') ||
                            lower.endsWith('.webp') ||
                            lower.endsWith('.bmp');
                        if (isImage) {
                          leading = Image.network(
                            src,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          );
                        } else {
                          // backend returned a non-image file (e.g. .txt) — show icon instead
                          leading = const Icon(
                            Icons.insert_drive_file,
                            size: 56,
                          );
                        }
                      } else {
                        final bytes = pf_readFileBytes(src);
                        if (bytes != null) {
                          leading = Image.memory(
                            bytes,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          );
                        } else {
                          leading = const Icon(Icons.receipt_long, size: 56);
                        }
                      }
                    } catch (_) {
                      leading = const Icon(Icons.receipt_long, size: 56);
                    }
                  }
                  Color statusColor;
                  switch (t.status.toLowerCase()) {
                    case 'sent':
                      statusColor = Colors.green.shade600;
                      break;
                    case 'complete':
                      statusColor = Colors.teal.shade600;
                      break;
                    case 'pending':
                    default:
                      statusColor = Colors.orange.shade600;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${t.agentName} — ${AppConfig.formatCurrency(t.amount)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: statusColor.withOpacity(0.8),
                                        ),
                                      ),
                                      child: Text(
                                        t.status.toUpperCase(),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  runSpacing: 6,
                                  spacing: 12,
                                  children: [
                                    Text('ID: ${t.id ?? '-'}'),
                                    Text('Receiver: ${t.receiverNumber}'),
                                    if ((t.txRef ?? '').isNotEmpty)
                                      Text('TX: ${t.txRef}'),
                                    if ((t.destination ?? '').isNotEmpty)
                                      Text('To: ${t.destination}'),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Agent fee: ${AppConfig.formatCurrency(t.agentFee)}',
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Marked sent'),
                                          ),
                                        );
                                        await LocalDb.instance.logAudit(
                                          'transfer_marked_sent',
                                          t.id.toString(),
                                        );
                                        setState(() => _load());
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed: ${prefs.statusCode}',
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      final db =
                                          await LocalDb.instance.database;
                                      await db.update(
                                        'transfers',
                                        {'status': 'sent', 'txRef': tx},
                                        where: 'id = ?',
                                        whereArgs: [t.id],
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Marked sent locally'),
                                        ),
                                      );
                                      await LocalDb.instance.logAudit(
                                        'transfer_marked_sent',
                                        t.id.toString(),
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
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _placeholder(String title, {String subtitle = ''}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard, size: 72, color: Colors.indigo.shade200),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTab() {
    final codeCtrl = TextEditingController(text: AppConfig.currencyCode);
    final symbolCtrl = TextEditingController(text: AppConfig.currencySymbol);
    int decimals = AppConfig.currencyDecimals;
    bool after = AppConfig.currencySymbolAfter;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Currency',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Currency code (e.g. ZAR)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: symbolCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Currency symbol (e.g. R)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Symbol after amount'),
                      const SizedBox(width: 8),
                      Switch(
                        value: after,
                        onChanged: (v) {
                          after = v;
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Decimal places'),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: decimals,
                        items: [0, 1, 2, 3, 4]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            decimals = v;
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          AppConfig.currencyCode = codeCtrl.text.trim();
                          AppConfig.currencySymbol = symbolCtrl.text.trim();
                          AppConfig.currencySymbolAfter = after;
                          AppConfig.currencyDecimals = decimals;
                          // Also ensure theme preference persists when saving here
                          try {
                            await AppConfig.save();
                          } catch (_) {}
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings saved')),
                          );
                          setState(() {});
                        },
                        child: const Text('Save'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Dark mode'),
                      const SizedBox(width: 8),
                      Switch(
                        value: AppConfig.darkMode,
                        onChanged: (v) async {
                          AppConfig.darkMode = v;
                          AppConfig.themeNotifier.value = v;
                          try {
                            await AppConfig.save();
                          } catch (_) {}
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Security',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Minimum password strength: ${AppConfig.passwordMinStrength.toStringAsFixed(2)}',
                          ),
                          Slider(
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            value: AppConfig.passwordMinStrength,
                            label: AppConfig.passwordMinStrength
                                .toStringAsFixed(2),
                            onChanged: (v) {
                              AppConfig.passwordMinStrength = v;
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Higher values require stronger passwords for registration.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Integrations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure external services (exchange rate providers, notifications, etc.)',
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Integration settings are not implemented yet',
                          ),
                        ),
                      );
                    },
                    child: const Text('Configure'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Recipients management (simple in-memory + LocalDb if available)
  Widget _recipientsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadRecipients(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showRecipientEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add recipient'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  return ListTile(
                    leading: const Icon(Icons.person_pin),
                    title: Text(r['name'] ?? r['number'] ?? '—'),
                    subtitle: Text(r['number'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showRecipientEditor(existing: r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteRecipient(r),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadRecipients() async {
    // try LocalDb if table exists else use empty list
    try {
      final db = await LocalDb.instance.database;
      final rows = await db.query('recipients');
      return rows;
    } catch (_) {
      return [];
    }
  }

  Future<void> _showRecipientEditor({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final numCtrl = TextEditingController(text: existing?['number'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add recipient' : 'Edit recipient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: numCtrl,
              decoration: const InputDecoration(labelText: 'Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = await LocalDb.instance.database;
      if (existing == null) {
        await db.insert('recipients', {
          'name': nameCtrl.text.trim(),
          'number': numCtrl.text.trim(),
        });
        await LocalDb.instance.logAudit(
          'recipient_added',
          nameCtrl.text.trim(),
        );
      } else {
        await db.update(
          'recipients',
          {'name': nameCtrl.text.trim(), 'number': numCtrl.text.trim()},
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
        await LocalDb.instance.logAudit(
          'recipient_updated',
          nameCtrl.text.trim(),
        );
      }
    } catch (_) {
      // fallback: do nothing (could persist to backend later)
    }
    setState(() {});
  }

  Future<void> _deleteRecipient(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recipient'),
        content: Text('Delete ${row['name'] ?? row['number']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = await LocalDb.instance.database;
      await db.delete('recipients', where: 'id = ?', whereArgs: [row['id']]);
      await LocalDb.instance.logAudit(
        'recipient_deleted',
        row['name'] ?? row['number'] ?? '',
      );
    } catch (_) {}
    setState(() {});
  }

  // Agents tab — simple list with toggles
  Widget _agentsTab() {
    // read agents from agents table
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LocalDb.instance.readAgents(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final list = snap.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showAgentEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add agent'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final a = list[i];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(a['name'] ?? '—'),
                    subtitle: Text(a['locationId'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showAgentEditor(existing: a),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteAgent(a['id']),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Agents are read directly from LocalDb.readAgents()

  Future<void> _showAgentEditor({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final locCtrl = TextEditingController(text: existing?['locationId'] ?? '');
    final statusCtrl = TextEditingController(
      text: existing?['status'] ?? 'active',
    );
    final commCtrl = TextEditingController(
      text: (existing?['commissionRate']?.toString() ?? '0'),
    );
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add agent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Agent name'),
            ),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(labelText: 'Location ID'),
            ),
            TextField(
              controller: statusCtrl,
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            TextField(
              controller: commCtrl,
              decoration: const InputDecoration(labelText: 'Commission rate'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (res != true) return;
    final id = existing != null
        ? existing['id'] as String
        : DateTime.now().millisecondsSinceEpoch.toString();
    final agent = {
      'id': id,
      'name': nameCtrl.text.trim(),
      'locationId': locCtrl.text.trim(),
      'status': statusCtrl.text.trim(),
      'dailyVolume': existing?['dailyVolume'] ?? 0,
      'commissionRate': double.tryParse(commCtrl.text) ?? 0,
    };
    try {
      await LocalDb.instance.upsertAgent(agent);
      final meta = '${agent['id']}:${agent['name']}';
      await LocalDb.instance.logAudit(
        existing == null ? 'agent_added' : 'agent_updated',
        meta,
      );
    } catch (_) {}
    setState(() {});
  }

  Future<void> _deleteAgent(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete agent'),
        content: const Text(
          'Delete this agent? This will not remove historical transfers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await LocalDb.instance.deleteAgentById(id);
      await LocalDb.instance.logAudit('agent_deleted', id);
    } catch (_) {}
    setState(() {});
  }

  // Users tab — simple in-memory list using backend/users if available
  Widget _usersTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadUsers(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final list = snap.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showUserEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add user'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final u = list[i];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(u['username'] ?? '—'),
                    subtitle: Text(u['role'] ?? 'user'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showUserEditor(existing: u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteUser(u),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    try {
      // If backend available, fetch; else read from local users table
      if (AppConfig.useBackend) {
        final list = await ApiService.fetchUsers();
        return list.cast<Map<String, dynamic>>();
      }
      final db = await LocalDb.instance.database;
      final rows = await db.query('users');
      return rows;
    } catch (_) {
      return [];
    }
  }

  Future<void> _showUserEditor({Map<String, dynamic>? existing}) async {
    final userCtrl = TextEditingController(text: existing?['username'] ?? '');
    final roleCtrl = TextEditingController(text: existing?['role'] ?? 'user');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add user' : 'Edit user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = await LocalDb.instance.database;
      if (existing == null) {
        await db.insert('users', {
          'username': userCtrl.text.trim(),
          'role': roleCtrl.text.trim(),
        });
        await LocalDb.instance.logAudit('user_added', userCtrl.text.trim());
      } else {
        await db.update(
          'users',
          {'username': userCtrl.text.trim(), 'role': roleCtrl.text.trim()},
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
        await LocalDb.instance.logAudit('user_updated', userCtrl.text.trim());
      }
    } catch (_) {}
    setState(() {});
  }

  Future<void> _deleteUser(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete user'),
        content: Text('Delete ${u['username']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = await LocalDb.instance.database;
      await db.delete('users', where: 'id = ?', whereArgs: [u['id']]);
      await LocalDb.instance.logAudit('user_deleted', u['username'] ?? '');
    } catch (_) {}
    setState(() {});
  }

  // Reports tab — simple report generator based on transfers
  Widget _reportsTab() {
    return FutureBuilder<List<Transfer>>(
      future: (AppConfig.useBackend
          ? ApiService.fetchTransfers()
          : LocalDb.instance.readAll()),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final list = snap.data ?? [];
        final total = list.fold<double>(0, (p, e) => p + e.amount);
        final byAgent = <String, double>{};
        for (final t in list) {
          byAgent[t.agentName] = (byAgent[t.agentName] ?? 0) + t.amount;
        }
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Card(
                child: ListTile(
                  title: const Text('Total transferred'),
                  trailing: Text(AppConfig.formatCurrency(total)),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: byAgent.entries
                      .map(
                        (e) => ListTile(
                          title: Text(e.key),
                          trailing: Text(AppConfig.formatCurrency(e.value)),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Notifications tab — templates list and simple send preview
  Widget _notificationsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LocalDb.instance.readNotifications(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final templates = snap.data ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () => _showNotificationEditor(),
                icon: const Icon(Icons.add),
                label: const Text('New template'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, i) {
                  final t = templates[i];
                  return ListTile(
                    leading: const Icon(Icons.mail),
                    title: Text(t['name'] ?? '—'),
                    subtitle: Text(t['body'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Preview: ${(t['body'] ?? '').replaceAll('{{amount}}', AppConfig.formatCurrency(123.45))}',
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showNotificationEditor(existing: t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete template'),
                                content: const Text('Delete this template?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await LocalDb.instance.deleteNotification(
                                t['id'] as int,
                              );
                              await LocalDb.instance.logAudit(
                                'notification_deleted',
                                t['name'] ?? '',
                              );
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNotificationEditor({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final bodyCtrl = TextEditingController(text: existing?['body'] ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'New template' : 'Edit template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: bodyCtrl,
              decoration: const InputDecoration(labelText: 'Body'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (existing == null) {
                final nid = await LocalDb.instance.insertNotification({
                  'name': nameCtrl.text.trim(),
                  'body': bodyCtrl.text.trim(),
                });
                await LocalDb.instance.logAudit(
                  'notification_created',
                  '$nid:${nameCtrl.text.trim()}',
                );
              } else {
                await LocalDb.instance.updateNotification(
                  existing['id'] as int,
                  {'name': nameCtrl.text.trim(), 'body': bodyCtrl.text.trim()},
                );
                await LocalDb.instance.logAudit(
                  'notification_updated',
                  '${existing['id']}:${nameCtrl.text.trim()}',
                );
              }
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Audit log tab — read from a simple local audit table if exists; otherwise show placeholder
  Widget _auditTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadAudit(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final rows = snap.data ?? [];
        if (rows.isEmpty)
          return _placeholder('Audit Log', subtitle: 'No audit entries yet.');
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(r['action'] ?? '—'),
              subtitle: Text(r['meta'] ?? ''),
              trailing: Text(r['created_at'] ?? ''),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadAudit() async {
    try {
      final db = await LocalDb.instance.database;
      final rows = await db.query('audit', orderBy: 'created_at DESC');
      return rows;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(onPressed: _exportCsv, icon: const Icon(Icons.download)),
          IconButton(
            onPressed: () => setState(() => _load()),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicator: BoxDecoration(
                  color: Colors.indigoAccent,
                  borderRadius: BorderRadius.circular(24),
                ),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 6),
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                tabs: const [
                  Tab(icon: Icon(Icons.swap_horiz), text: 'Transfers'),
                  Tab(icon: Icon(Icons.people), text: 'Recipients'),
                  Tab(icon: Icon(Icons.store), text: 'Agents'),
                  Tab(icon: Icon(Icons.person), text: 'Users'),
                  Tab(icon: Icon(Icons.assessment), text: 'Reports'),
                  Tab(icon: Icon(Icons.settings), text: 'Settings'),
                  Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
                  Tab(icon: Icon(Icons.history), text: 'Audit Log'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _transfersTab(),
          _recipientsTab(),
          _agentsTab(),
          _usersTab(),
          _reportsTab(),
          _settingsTab(),
          _notificationsTab(),
          _auditTab(),
        ],
      ),
    );
  }
}

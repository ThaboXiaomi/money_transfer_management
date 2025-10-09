// don't import dart:io directly; use platform helpers for file ops
import 'package:flutter/material.dart';
import '../models/transfer.dart';
import '../services/local_db.dart';
import '../services/config.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../services/platform_file.dart';
import '../services/app_init.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Transfer>> _transfers;
  late TabController _tabController;
  bool? _lastConnOk;
  int? _lastConnRttMs;
  String? _lastConnChecked;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _load();
    _loadConnStatus();
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

  Future<void> _loadConnStatus() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _lastConnOk = sp.getBool('lastConnOk');
        _lastConnRttMs = sp.getInt('lastConnRttMs');
        _lastConnChecked = sp.getString('lastConnChecked');
      });
    } catch (_) {}
  }

  Future<void> _exportCsv() async {
    if (AppConfig.useBackend) {
      final uri = Uri.parse('${AppConfig.backendBase}/transfers/export/csv');
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('jwt');
      final headers = token != null ? {'Authorization': 'Bearer $token'} : null;
      final prefs = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (prefs.statusCode == 200) {
        final bytes = prefs.bodyBytes;
        if (kIsWeb) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CSV ready (web): saved on server')),
            );
          }
        } else {
          final dir = await getTemporaryDirectory();
          if (!mounted) return;
          final filename =
              'transfers_${DateTime.now().millisecondsSinceEpoch}.csv';
          final path = pf_writeFileBytesSync(dir.path, filename, bytes);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('CSV saved to $path')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: ${prefs.statusCode}')),
          );
        }
      }
    } else {
      final list = await LocalDb.instance.readAll();
      if (!mounted) return;
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
        if (!mounted) return;
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
              context,
              'Total transferred',
              AppConfig.formatCurrency(total),
              Icons.attach_money,
            ),
            _statTile(context, 'Transfers', count.toString(), Icons.swap_horiz),
            _statTile(
              context,
              'Pending',
              pending.toString(),
              Icons.hourglass_empty,
            ),

            _statTile(context, 'Sent', sent.toString(), Icons.send),
          ],
        ),
      ),
    );
  }

  Widget _statTile(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(child: _buildSummary(list)),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _exportCsv,
                        icon: const Icon(Icons.download),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _load()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final t = list[i];
                  ImageProvider<Object>? imageProvider;
                  if (t.screenshotPath.isNotEmpty) {
                    try {
                      final src = t.screenshotPath.trim();
                      if (src.startsWith('data:image')) {
                        final bytes = UriData.parse(src).contentAsBytes();
                        imageProvider = MemoryImage(bytes);
                      } else if (AppConfig.useBackend &&
                          (src.startsWith('http://') ||
                              src.startsWith('https://'))) {
                        final lower = src.toLowerCase();
                        final isImage =
                            lower.endsWith('.png') ||
                            lower.endsWith('.jpg') ||
                            lower.endsWith('.jpeg') ||
                            lower.endsWith('.gif') ||
                            lower.endsWith('.webp') ||
                            lower.endsWith('.bmp');
                        if (isImage) imageProvider = NetworkImage(src);
                      } else {
                        final bytes = pf_readFileBytes(src);
                        if (bytes != null) imageProvider = MemoryImage(bytes);
                      }
                    } catch (_) {
                      imageProvider = null;
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
                    elevation: 1,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage: imageProvider,
                        child: imageProvider == null
                            ? const Icon(Icons.receipt_long, size: 28)
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${t.agentName} — ${AppConfig.formatCurrency(t.amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Chip(
                            backgroundColor: statusColor.withAlpha(
                              (0.12 * 255).toInt(),
                            ),
                            label: Text(
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
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
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 20,
                                height: 20,
                              ),
                              iconSize: 16,
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              onPressed: () => _markTransferSent(t),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            width: 28,
                            height: 20,
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              icon: const Icon(Icons.more_vert),
                              onSelected: (v) async {
                                if (v == 'delete') {
                                  await _confirmAndDeleteTransfer(t);
                                } else if (v == 'edit') {
                                  await _showEditTransferDialog(t);
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
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
            Icon(
              Icons.dashboard,
              size: 72,
              color: Theme.of(
                context,
              ).colorScheme.primary.withAlpha((0.2 * 255).toInt()),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markTransferSent(Transfer t) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as sent'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Transaction reference'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final tx = ctrl.text.trim();
    if (AppConfig.useBackend) {
      final id = t.id;
      final uri = Uri.parse('${AppConfig.backendBase}/transfers/$id/mark_sent');
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('jwt');
      final headers = token != null ? {'Authorization': 'Bearer $token'} : null;
      final prefs = await http.post(uri, body: {'txRef': tx}, headers: headers);
      if (prefs.statusCode == 200) {
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Marked sent')));
        }
        await LocalDb.instance.logAudit(
          'transfer_marked_sent',
          t.id.toString(),
        );
        setState(() => _load());
      } else {
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${prefs.statusCode}')),
          );
        }
      }
    } else {
      final db = await LocalDb.instance.database;
      await db.update(
        'transfers',
        {'status': 'sent', 'txRef': tx},
        where: 'id = ?',
        whereArgs: [t.id],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marked sent locally')));
      await LocalDb.instance.logAudit('transfer_marked_sent', t.id.toString());
      setState(() => _load());
    }
  }

  Future<void> _confirmAndDeleteTransfer(Transfer t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete transfer'),
        content: const Text('Delete this transfer? This cannot be undone.'),
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
    if (!mounted) return;
    // If backend mode, call server delete endpoint
    if (AppConfig.useBackend) {
      if (kIsWeb) {
        // Web + backend: still call backend over HTTP
      }
      try {
        final sp = await SharedPreferences.getInstance();
        final token = sp.getString('jwt');
        final headers = token != null
            ? {'Authorization': 'Bearer $token'}
            : null;
        final uri = Uri.parse('${AppConfig.backendBase}/transfers/${t.id}');
        final resp = await http.delete(uri, headers: headers);
        if (resp.statusCode == 200 || resp.statusCode == 204) {
          if (!mounted) return;
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Deleted')));
          }
          await LocalDb.instance.logAudit('transfer_deleted', t.id.toString());
          setState(() => _load());
          return;
        } else {
          if (!mounted) return;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Delete failed: ${resp.statusCode}')),
            );
          }
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        return;
      }
    }

    // Local mode (not backend)
    if (kIsWeb) {
      // No sqlite on web: simulate delete
      await LocalDb.instance.logAudit('transfer_deleted', t.id.toString());
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleted (web)')));
      }
      setState(() => _load());
      return;
    }
    try {
      final db = await LocalDb.instance.database;
      await db.delete('transfers', where: 'id = ?', whereArgs: [t.id]);
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleted')));
      }
      await LocalDb.instance.logAudit('transfer_deleted', t.id.toString());
      setState(() => _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _showEditTransferDialog(Transfer t) async {
    final agentCtrl = TextEditingController(text: t.agentName);
    final receiverCtrl = TextEditingController(text: t.receiverNumber);
    final amountCtrl = TextEditingController(text: t.amount.toString());
    final txCtrl = TextEditingController(text: t.txRef ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit transfer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: agentCtrl,
                decoration: const InputDecoration(labelText: 'Agent name'),
              ),
              TextField(
                controller: receiverCtrl,
                decoration: const InputDecoration(labelText: 'Receiver number'),
              ),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: txCtrl,
                decoration: const InputDecoration(labelText: 'Transaction ref'),
              ),
            ],
          ),
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
    if (!mounted) return;
    final updatedMap = t.toMap();
    updatedMap['agentName'] = agentCtrl.text.trim();
    updatedMap['receiverNumber'] = receiverCtrl.text.trim();
    updatedMap['amount'] = double.tryParse(amountCtrl.text) ?? t.amount;
    updatedMap['txRef'] = txCtrl.text.trim();
    // Send update to backend or local DB
    if (AppConfig.useBackend) {
      try {
        final sp = await SharedPreferences.getInstance();
        final token = sp.getString('jwt');
        final headers = token != null
            ? {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              }
            : {'Content-Type': 'application/json'};
        final uri = Uri.parse('${AppConfig.backendBase}/transfers/${t.id}');
        final resp = await http.put(
          uri,
          headers: headers,
          body: jsonEncode(updatedMap),
        );
        if (resp.statusCode == 200) {
          if (!mounted) return;
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Updated')));
          }
          await LocalDb.instance.logAudit('transfer_updated', t.id.toString());
          setState(() => _load());
          return;
        } else {
          if (!mounted) return;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Update failed: ${resp.statusCode}')),
            );
          }
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
        return;
      }
    }

    // Local DB update
    try {
      if (kIsWeb) {
        // No sqlite: simulate update
        await LocalDb.instance.logAudit('transfer_updated', t.id.toString());
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Updated (web)')));
        }
        setState(() => _load());
        return;
      }
      final db = await LocalDb.instance.database;
      await db.update(
        'transfers',
        updatedMap,
        where: 'id = ?',
        whereArgs: [t.id],
      );
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Updated')));
      }
      await LocalDb.instance.logAudit('transfer_updated', t.id.toString());
      setState(() => _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
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
                  const SizedBox(height: 12),
                  // Backend override controls: allow runtime editing and detection
                  Builder(
                    builder: (ctx) {
                      final backendCtrl = TextEditingController(
                        text: AppConfig.backendBase,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          if (_lastConnOk != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Text(
                                    'Last check: ${_lastConnChecked ?? '-'}',
                                  ),
                                  const SizedBox(width: 12),
                                  if (_lastConnOk == true)
                                    Text(
                                      'OK',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                      ),
                                    )
                                  else
                                    Text(
                                      'Failed',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  if (_lastConnRttMs != null)
                                    Text('RTT: ${_lastConnRttMs}ms'),
                                ],
                              ),
                            ),
                          const Text(
                            'Backend',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: backendCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Backend base URL',
                              helperText: 'e.g. http://192.168.1.100:8000',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  final val = backendCtrl.text.trim();
                                  if (val.isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('Enter a backend URL'),
                                      ),
                                    );
                                    return;
                                  }
                                  AppInit.setBackendBase(val);
                                  setState(() {});
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('Backend saved'),
                                    ),
                                  );
                                },
                                child: const Text('Save'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () async {
                                  // Re-run detection/probe (clears nothing, tries available candidates)
                                  await AppInit.init();
                                  setState(() {});
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Re-probed backend (see logs)',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Detect'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () async {
                                  // Test connection to the configured backend.
                                  final base = AppConfig.backendBase;
                                  if (base.isEmpty) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('No backend configured'),
                                      ),
                                    );
                                    return;
                                  }
                                  final testPaths = ['/docs', '/'];
                                  bool ok = false;
                                  String msg = '';
                                  for (final p in testPaths) {
                                    try {
                                      final uri = Uri.parse(base + p);
                                      final resp = await http
                                          .get(uri)
                                          .timeout(const Duration(seconds: 5));
                                      if (!mounted) return;
                                      if (resp.statusCode >= 200 &&
                                          resp.statusCode < 400) {
                                        ok = true;
                                        msg = 'OK: ${resp.statusCode} ${p}';
                                        break;
                                      } else {
                                        msg = 'HTTP ${resp.statusCode} at ${p}';
                                      }
                                    } catch (e) {
                                      msg = e.toString();
                                    }
                                  }
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Connection OK — $msg'
                                            : 'Connection failed — $msg',
                                      ),
                                      backgroundColor: ok
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  );
                                },
                                child: const Text('Test Connection'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () async {
                                  try {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.remove('backendOverride');
                                  } catch (_) {}
                                  await AppInit.init();
                                  setState(() {});
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Cleared override and re-probed',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Clear Override'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
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
    if (!mounted) return;
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
    if (!mounted) return;
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
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _assignMissingAgentIds,
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Assign Missing IDs'),
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
                        // Show agent id if present
                        if ((a['id'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(a['id'].toString()),
                          )
                        else
                          IconButton(
                            tooltip: 'Assign ID',
                            icon: const Icon(Icons.how_to_reg),
                            onPressed: () => _assignAgentId(a),
                          ),
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

  // Assign a generated id to a single agent if missing
  Future<void> _assignAgentId(Map<String, dynamic> agent) async {
    try {
      final currentId = (agent['id'] ?? '').toString();
      if (currentId.isNotEmpty) return; // already has id
      final newId = 'AG' + DateTime.now().millisecondsSinceEpoch.toString();
      final updated = Map<String, dynamic>.from(agent);
      updated['id'] = newId;
      await LocalDb.instance.upsertAgent(updated);
      await LocalDb.instance.logAudit(
        'agent_assigned_id',
        '${newId}:${updated['name'] ?? ''}',
      );
    } catch (_) {}
    setState(() {});
  }

  // Bulk assign missing IDs to agents without an id
  Future<void> _assignMissingAgentIds() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Missing IDs'),
        content: const Text(
          'Assign generated Agent IDs to agents missing one?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final agents = await LocalDb.instance.readAgents();
      for (final a in agents) {
        if ((a['id'] ?? '').toString().isEmpty) {
          final newId = 'AG' + DateTime.now().millisecondsSinceEpoch.toString();
          final updated = Map<String, dynamic>.from(a);
          updated['id'] = newId;
          await LocalDb.instance.upsertAgent(updated);
          await LocalDb.instance.logAudit(
            'agent_assigned_id',
            '${newId}:${updated['name'] ?? ''}',
          );
        }
      }
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
                              if (!mounted) return;
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor:
            Theme.of(context).textTheme.titleLarge?.color ??
            Theme.of(context).colorScheme.onBackground,
        elevation: 0,
        actions: [
          IconButton(onPressed: _exportCsv, icon: const Icon(Icons.download)),
          IconButton(
            onPressed: () => setState(() => _load()),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
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
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/role-selection',
                (r) => false,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.black54,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.5, color: Colors.indigo),
            insets: EdgeInsets.symmetric(horizontal: 16.0),
          ),
          indicatorSize: TabBarIndicatorSize.label,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          tabs: [
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.swap_horiz, size: 16),
                  const SizedBox(height: 2),
                  const SizedBox(
                    height: 14,
                    child: Text(
                      'Transfers',
                      style: TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, size: 16),
                  const SizedBox(height: 2),
                  const SizedBox(
                    height: 14,
                    child: Text(
                      'Recipients',
                      style: TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.store, size: 16),
                  const SizedBox(height: 2),
                  const SizedBox(
                    height: 14,
                    child: Text(
                      'Agents',
                      style: TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(height: 2),
                  const SizedBox(
                    height: 14,
                    child: Text(
                      'Users',
                      style: TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assessment, size: 16),
                  const SizedBox(height: 2),
                  const SizedBox(
                    height: 14,
                    child: Text(
                      'Reports',
                      style: TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.settings, size: 16),
                  const SizedBox(height: 2),
                  const SizedBox(
                    height: 14,
                    child: Text(
                      'Settings',
                      style: TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications, size: 16),
                  const SizedBox(height: 2),
                  const SizedBox(
                    height: 14,
                    child: Text(
                      'Notifications',
                      style: TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 16),
                  const SizedBox(height: 2),
                  const SizedBox(
                    height: 14,
                    child: Text(
                      'Audit Log',
                      style: TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

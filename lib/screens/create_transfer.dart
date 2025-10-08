import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/transfer.dart';
import '../services/api_service.dart';
import '../services/config.dart';
import '../services/local_db.dart';
import '../services/pricing.dart';

class CreateTransferScreen extends StatefulWidget {
  const CreateTransferScreen({super.key});

  @override
  State<CreateTransferScreen> createState() => _CreateTransferScreenState();
}

class _CreateTransferScreenState extends State<CreateTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _agentCtrl = TextEditingController();
  String? _selectedAgentId;
  List<Map<String, dynamic>> _agents = [];
  bool _useDropdown = true;
  final _senderCtrl = TextEditingController();
  final _receiverCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _chargeCtrl = TextEditingController(text: '0');
  final _agentFeeCtrl = TextEditingController(text: '0');
  final _txRefCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  String _status = 'pending';
  String _screenshotPath = '';
  bool _submitting = false;

  Future<void> _pickImage() async {
    final p = ImagePicker();
    final x = await p.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (x != null) {
      if (!mounted) return;
      setState(() => _screenshotPath = x.path);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final t = Transfer(
      agentName: _agentCtrl.text.trim(),
      agentId: _selectedAgentId,
      senderNumber: _senderCtrl.text.trim(),
      receiverNumber: _receiverCtrl.text.trim(),
      amount: double.tryParse(_amountCtrl.text) ?? 0,
      charge: double.tryParse(_chargeCtrl.text) ?? 0,
      agentFee: double.tryParse(_agentFeeCtrl.text) ?? 0,
      screenshotPath: _screenshotPath,
      status: _status,
      txRef: _txRefCtrl.text.trim(),
      destination: _destinationCtrl.text.trim(),
    );

    try {
      if (AppConfig.useBackend) {
        await ApiService.uploadTransfer(
          t,
          destination: t.destination ?? '',
          txRef: t.txRef ?? '',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transfer uploaded')));
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        await LocalDb.instance.createTransfer(t);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transfer saved locally')));
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loadAgents() async {
    try {
      final rows = await LocalDb.instance.readAgents();
      setState(() {
        _agents = rows;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _agentCtrl.dispose();
    _senderCtrl.dispose();
    _receiverCtrl.dispose();
    _amountCtrl.dispose();
    _chargeCtrl.dispose();
    _agentFeeCtrl.dispose();
    _txRefCtrl.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  void _recalculateFees() {
    final amt = double.tryParse(_amountCtrl.text) ?? 0.0;
    final charge = Pricing.getCharge(amt);
    final agentFee = double.parse((charge * 0.3).toStringAsFixed(2));
    _chargeCtrl.text = charge.toStringAsFixed(2);
    _agentFeeCtrl.text = agentFee.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Transfer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                if (_useDropdown)
                  DropdownButtonFormField<String>(
                    value: _selectedAgentId,
                    decoration: const InputDecoration(
                      labelText: 'Referring agent',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Select agent (or choose Other)'),
                      ),
                      ..._agents.map(
                        (a) => DropdownMenuItem(
                          value: a['id'] as String,
                          child: Text(a['name'] ?? a['id']),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: 'OTHER',
                        child: Text('Other (enter manually)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == 'OTHER') {
                        setState(() {
                          _useDropdown = false;
                          _selectedAgentId = null;
                        });
                      } else {
                        setState(() {
                          _selectedAgentId = v;
                          _agentCtrl.text =
                              _agents.firstWhere(
                                (e) => e['id'] == v,
                                orElse: () => {},
                              )['name'] ??
                              '';
                        });
                      }
                    },
                    validator: (v) =>
                        (_agentCtrl.text.trim().isEmpty && v == null)
                        ? 'Select or enter agent'
                        : null,
                  )
                else
                  TextFormField(
                    controller: _agentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Agent name or ID',
                    ),
                    validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _senderCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Sender number',
                        ),
                        validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _receiverCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Receiver number',
                        ),
                        validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Amount'),
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                            ? 'Invalid amount'
                            : null,
                        onChanged: (_) => setState(_recalculateFees),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _chargeCtrl,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Charge'),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _agentFeeCtrl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Agent Fee (30%)',
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Charge',
                              style: TextStyle(color: Colors.black54),
                            ),
                            Text(
                              'R' +
                                  (_chargeCtrl.text.isEmpty
                                      ? '0.00'
                                      : _chargeCtrl.text),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Agent fee (30%)',
                              style: TextStyle(color: Colors.black54),
                            ),
                            Text(
                              'R' +
                                  (_agentFeeCtrl.text.isEmpty
                                      ? '0.00'
                                      : _agentFeeCtrl.text),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Payable',
                              style: TextStyle(color: Colors.black54),
                            ),
                            Builder(
                              builder: (_) {
                                final amt =
                                    double.tryParse(_amountCtrl.text) ?? 0.0;
                                final charge =
                                    double.tryParse(_chargeCtrl.text) ?? 0.0;
                                final total = amt + charge;
                                return Text(
                                  'R' + total.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _destinationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Destination (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _txRefCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Transaction reference (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo),
                      label: const Text('Attach screenshot'),
                    ),
                    const SizedBox(width: 12),
                    if (_screenshotPath.isNotEmpty)
                      Expanded(
                        child: Text(
                          _screenshotPath.split('/').last,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(),
                        )
                      : const Text('Submit transfer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }
}

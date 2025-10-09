import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/app_init.dart';
import '../models/transfer.dart';
import '../services/local_db.dart';
import '../services/config.dart';
import '../services/api_service.dart';
import '../services/pricing.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _agentController = TextEditingController();
  final _senderController = TextEditingController();
  final _receiverController = TextEditingController();
  final _amountController = TextEditingController();
  final _destinationController = TextEditingController();
  final _txRefController = TextEditingController();
  File? _image;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _agentController.dispose();
    _senderController.dispose();
    _receiverController.dispose();
    _amountController.dispose();
    _destinationController.dispose();
    _txRefController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    setState(() {});
  }

  Future pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) {
      if (!mounted) return;
      setState(() => _image = File(x.path));
    }
  }

  double computeCharge(double amount) {
    return Pricing.getCharge(amount);
  }

  void submit() async {
    if (!_formKey.currentState!.validate() || _image == null) return;
    final amt = double.tryParse(_amountController.text) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    final charge = computeCharge(amt);
    final agentFee = charge * 0.30; // 30%

    final t = Transfer(
      agentName: _agentController.text.trim(),
      senderNumber: _senderController.text.trim(),
      receiverNumber: _receiverController.text.trim(),
      amount: amt,
      charge: charge,
      agentFee: agentFee,
      screenshotPath: _image!.path,
    );

    await LocalDb.instance.createTransfer(t);

    if (AppConfig.useBackend) {
      // try uploading to backend
      try {
        await ApiService.uploadTransfer(
          t,
          destination: _destinationController.text.trim(),
          txRef: _txRefController.text.trim(),
        );
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Uploaded to backend')));
        }
      } catch (e) {
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      }
    } else {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transfer saved locally')));
      }
    }
    if (!mounted) return;
    _formKey.currentState!.reset();
    if (!mounted) return;
    setState(() => _image = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Portal'),
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
          tabs: const [
            Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, size: 16),
                  SizedBox(height: 2),
                  SizedBox(
                    height: 14,
                    child: Text(
                      'Send',
                      style: TextStyle(fontSize: 11),
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
                  Icon(Icons.history, size: 16),
                  SizedBox(height: 2),
                  SizedBox(
                    height: 14,
                    child: Text(
                      'History',
                      style: TextStyle(fontSize: 11),
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
                  Icon(Icons.person, size: 16),
                  SizedBox(height: 2),
                  SizedBox(
                    height: 14,
                    child: Text(
                      'Profile',
                      style: TextStyle(fontSize: 11),
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
        children: [_sendTab(), _historyTab(), _profileTab()],
      ),
    );
  }

  Widget _sendTab() {
    final amt = double.tryParse(_amountController.text) ?? 0.0;
    final charge = computeCharge(amt);
    final agentFee = charge * 0.30;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _agentController,
                decoration: const InputDecoration(labelText: 'Agent Name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _senderController,
                decoration: const InputDecoration(labelText: 'Sender Number'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _receiverController,
                decoration: const InputDecoration(labelText: 'Receiver Number'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  labelText: 'Destination (bank/account)',
                ),
              ),
              TextFormField(
                controller: _txRefController,
                decoration: const InputDecoration(
                  labelText: 'Transaction reference (optional)',
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(AppConfig.formatCurrency(charge)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Agent fee (30%)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(AppConfig.formatCurrency(agentFee)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Payable',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(AppConfig.formatCurrency(amt + charge)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _image == null
                  ? const Text('No screenshot chosen')
                  : Image.file(_image!, height: 200),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: pickImage,
                    icon: const Icon(Icons.photo),
                    label: const Text('Pick Screenshot'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: submit,
                    child: const Text('Upload & Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyTab() {
    return FutureBuilder<List<Transfer>>(
      future: LocalDb.instance.readAll(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final list = snap.data ?? [];
        if (list.isEmpty) return const Center(child: Text('No transfers yet'));
        // If agent name provided, filter
        final agent = _agentController.text.trim();
        final filtered = agent.isEmpty
            ? list
            : list.where((t) => t.agentName == agent).toList();
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final t = filtered[i];
            return ListTile(
              title: Text(
                '${t.agentName} — ${AppConfig.formatCurrency(t.amount)}',
              ),
              subtitle: Text('To: ${t.destination ?? '-'} • ${t.status}'),
              trailing: Text(AppConfig.formatCurrency(t.agentFee)),
            );
          },
        );
      },
    );
  }

  Widget _profileTab() {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: _agentController.text);
    final locCtrl = TextEditingController();
    final statusCtrl = TextEditingController(text: 'active');
    final commCtrl = TextEditingController(text: '0');

    Future<void> _saveProfile() async {
      final id = idCtrl.text.trim().isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : idCtrl.text.trim();
      final agent = {
        'id': id,
        'name': nameCtrl.text.trim(),
        'locationId': locCtrl.text.trim(),
        'status': statusCtrl.text.trim(),
        'dailyVolume': 0,
        'commissionRate': double.tryParse(commCtrl.text) ?? 0,
      };
      try {
        await LocalDb.instance.upsertAgent(agent);
        await LocalDb.instance.logAudit(
          'agent_profile_saved',
          '$id:${agent['name']}',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: idCtrl,
            decoration: const InputDecoration(
              labelText: 'Agent ID (leave blank to create)',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Agent Name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: locCtrl,
            decoration: const InputDecoration(labelText: 'Location ID'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: statusCtrl,
            decoration: const InputDecoration(labelText: 'Status'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: commCtrl,
            decoration: const InputDecoration(labelText: 'Commission rate (%)'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saveProfile,
            child: const Text('Save Profile'),
          ),
        ],
      ),
    );
  }
}

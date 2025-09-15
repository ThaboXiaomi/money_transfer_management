import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

class _AgentScreenState extends State<AgentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _agentController = TextEditingController();
  final _senderController = TextEditingController();
  final _receiverController = TextEditingController();
  final _amountController = TextEditingController();
  final _destinationController = TextEditingController();
  final _txRefController = TextEditingController();
  File? _image;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    setState(() {});
  }

  Future pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _image = File(x.path));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploaded to backend')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transfer saved locally')));
    }
    _formKey.currentState!.reset();
    setState(() => _image = null);
  }

  @override
  Widget build(BuildContext context) {
    final amt = double.tryParse(_amountController.text) ?? 0.0;
    final charge = computeCharge(amt);
    final agentFee = charge * 0.30;

    return Scaffold(
      appBar: AppBar(title: const Text('Agent Portal')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _agentController,
                  decoration: const InputDecoration(labelText: 'Agent Name'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _senderController,
                  decoration: const InputDecoration(labelText: 'Sender Number'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _receiverController,
                  decoration: const InputDecoration(
                    labelText: 'Receiver Number',
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
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
      ),
    );
  }
}

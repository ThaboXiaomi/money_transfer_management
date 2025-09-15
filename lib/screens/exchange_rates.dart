import 'package:flutter/material.dart';
import '../services/config.dart';
import '../services/api_service.dart';

class ExchangeRatesScreen extends StatefulWidget {
  const ExchangeRatesScreen({super.key});

  @override
  State<ExchangeRatesScreen> createState() => _ExchangeRatesScreenState();
}

class _ExchangeRatesScreenState extends State<ExchangeRatesScreen> {
  final List<Map<String, dynamic>> _rates = [
    {'pair': 'USD/EEK', 'rate': 1.0},
  ];

  void _addRate() {
    final pairCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pairCtrl,
              decoration: const InputDecoration(
                labelText: 'Pair (e.g. USD/ETB)',
              ),
            ),
            TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Rate'),
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
              final pair = pairCtrl.text.trim();
              final rate = double.tryParse(rateCtrl.text) ?? 0;
              if (pair.isEmpty || rate <= 0) return;
              setState(() => _rates.insert(0, {'pair': pair, 'rate': rate}));
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exchange Rates'),
        actions: [IconButton(onPressed: _addRate, icon: const Icon(Icons.add))],
      ),
      body: ListView.builder(
        itemCount: _rates.length,
        itemBuilder: (context, i) {
          final r = _rates[i];
          return ListTile(
            title: Text(r['pair'] as String),
            trailing: Text((r['rate'] as double).toStringAsFixed(4)),
          );
        },
      ),
    );
  }
}

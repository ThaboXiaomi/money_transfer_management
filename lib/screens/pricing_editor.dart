import 'package:flutter/material.dart';

class PricingEditorScreen extends StatefulWidget {
  const PricingEditorScreen({super.key});

  @override
  State<PricingEditorScreen> createState() => _PricingEditorScreenState();
}

class _PricingEditorScreenState extends State<PricingEditorScreen> {
  final List<Map<String, dynamic>> _rules = [];

  void _showRuleEditor({Map<String, dynamic>? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final minCtrl = TextEditingController(
      text: existing?['min']?.toString() ?? '',
    );
    final maxCtrl = TextEditingController(
      text: existing?['max']?.toString() ?? '',
    );
    final feeCtrl = TextEditingController(
      text: existing?['fee']?.toString() ?? '',
    );

    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(existing == null ? 'Add Rule' : 'Edit Rule'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: minCtrl,
                decoration: const InputDecoration(labelText: 'Min amount'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: maxCtrl,
                decoration: const InputDecoration(labelText: 'Max amount'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: feeCtrl,
                decoration: const InputDecoration(labelText: 'Fee (%)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final min = double.tryParse(minCtrl.text) ?? 0.0;
              final max = double.tryParse(maxCtrl.text) ?? double.infinity;
              final fee = double.tryParse(feeCtrl.text) ?? 0.0;
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }
              final map = {'name': name, 'min': min, 'max': max, 'fee': fee};
              setState(() {
                if (index != null)
                  _rules[index] = map;
                else
                  _rules.add(map);
              });
              Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pricing Editor')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.rule),
                title: const Text('Fee rules'),
                subtitle: const Text('Define fees applied to transfers'),
                trailing: ElevatedButton.icon(
                  onPressed: () => _showRuleEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add rule'),
                ),
              ),
            ),
            Expanded(
              child: _rules.isEmpty
                  ? const Center(
                      child: Text(
                        'No pricing rules. Tap "Add rule" to create one.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _rules.length,
                      itemBuilder: (context, i) {
                        final r = _rules[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(r['name'] as String),
                            subtitle: Text(
                              'Range: ${r['min']} - ${r['max']}  •  Fee: ${r['fee']}%',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _showRuleEditor(existing: r, index: i),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () =>
                                      setState(() => _rules.removeAt(i)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

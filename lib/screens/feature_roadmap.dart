import 'package:flutter/material.dart';

class FeatureRoadmapScreen extends StatefulWidget {
  const FeatureRoadmapScreen({super.key});

  @override
  State<FeatureRoadmapScreen> createState() => _FeatureRoadmapScreenState();
}

class _FeatureRoadmapScreenState extends State<FeatureRoadmapScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  static final List<_RoadmapFeature> _features = [
    for (var i = 1; i <= 150; i++)
      _RoadmapFeature(
        id: i,
        category: _categoryFor(i),
        title: 'Feature #$i: ${_titleFor(i)}',
        priority: i <= 40
            ? 'P0'
            : i <= 90
            ? 'P1'
            : 'P2',
      ),
  ];

  static String _categoryFor(int i) {
    if (i <= 15) return 'Security';
    if (i <= 30) return 'Fraud & Risk';
    if (i <= 45) return 'Wallet & Ledger';
    if (i <= 60) return 'Payments & Transfers';
    if (i <= 75) return 'KYC / AML';
    if (i <= 90) return 'User Experience';
    if (i <= 105) return 'Operations';
    if (i <= 120) return 'Admin & Governance';
    if (i <= 135) return 'Analytics';
    return 'Platform & Integrations';
  }

  static String _titleFor(int i) {
    const titles = [
      'Multi-factor authentication',
      'Step-up authentication for risky actions',
      'Trusted device management',
      'Biometric unlock',
      'Session revocation dashboard',
      'Transfer signing with PIN',
      'Password breach detection',
      'IP reputation checks',
      'Geo-velocity anomaly detection',
      'Behavioral fraud scoring',
      'Sanctions list screening',
      'PEP and adverse media matching',
      'Suspicious activity case workflow',
      'Real-time transaction risk scoring',
      'Fraud analyst cockpit',
      'Double-entry ledger core',
      'Available vs pending balances',
      'Hold and release funds',
      'Wallet-to-wallet transfers',
      'Scheduled transfers',
      'Recurring payments',
      'Transfer templates',
      'Dynamic fee engine',
      'FX quote lock window',
      'Multi-currency wallets',
      'Transfer routing engine',
      'Smart retry for partner downtime',
      'Payout orchestration',
      'Batch payouts',
      'Webhook delivery and retries',
      'KYC tiering',
      'ID verification flow',
      'Liveness and selfie match',
      'Proof-of-address verification',
      'Business onboarding (KYB)',
      'UBO management',
      'Compliance review queue',
      'Transaction monitoring rules',
      'AML alert triage',
      'Regulatory report export',
      'Transfer progress timeline',
      'One-tap repeat transfer',
      'Recipient favorites',
      'Payment links',
      'QR send and receive',
      'In-app notification center',
      'Push notifications by event type',
      'In-app support chat',
      'Multilingual localization',
      'Accessibility improvements (WCAG)',
    ];
    return titles[(i - 1) % titles.length];
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _features.where((f) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return f.title.toLowerCase().contains(q) ||
          f.category.toLowerCase().contains(q) ||
          f.priority.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('150-Feature Roadmap')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search roadmap features',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} / ${_features.length} features',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final f = filtered[i];
                  return Card(
                    child: ListTile(
                      title: Text(f.title),
                      subtitle: Text('${f.category} • Priority ${f.priority}'),
                      leading: CircleAvatar(child: Text(f.id.toString())),
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

class _RoadmapFeature {
  final int id;
  final String title;
  final String category;
  final String priority;

  const _RoadmapFeature({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
  });
}

import 'package:flutter/material.dart';

class ExchangeRatesScreen extends StatelessWidget {
  const ExchangeRatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exchange Rates')),
      body: const Center(child: Text('Manage exchange rates')),
    );
  }
}

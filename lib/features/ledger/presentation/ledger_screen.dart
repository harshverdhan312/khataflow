import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LedgerScreen extends ConsumerWidget {
  final String merchantId;

  const LedgerScreen({
    super.key,
    required this.merchantId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Ledger'),
      ),
      body: Center(
        child: Text('Ledger for merchant: $merchantId'),
      ),
    );
  }
}

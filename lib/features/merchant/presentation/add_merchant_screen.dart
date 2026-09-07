import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddMerchantScreen extends ConsumerWidget {
  const AddMerchantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Merchant'),
      ),
      body: const Center(
        child: Text('Add Merchant Flow'),
      ),
    );
  }
}

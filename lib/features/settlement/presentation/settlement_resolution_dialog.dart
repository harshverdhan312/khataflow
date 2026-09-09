import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../domain/settlement.dart';
import 'settlement_providers.dart';

class SettlementResolutionDialog extends ConsumerStatefulWidget {
  final Settlement settlement;
  final String merchantName;

  const SettlementResolutionDialog({
    super.key,
    required this.settlement,
    required this.merchantName,
  });

  static Future<void> show(
    BuildContext context, {
    required Settlement settlement,
    required String merchantName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SettlementResolutionDialog(
        settlement: settlement,
        merchantName: merchantName,
      ),
    );
  }

  @override
  ConsumerState<SettlementResolutionDialog> createState() =>
      _SettlementResolutionDialogState();
}

class _SettlementResolutionDialogState
    extends ConsumerState<SettlementResolutionDialog> {
  final _utrController = TextEditingController();
  final _txnIdController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _utrController.dispose();
    _txnIdController.dispose();
    super.dispose();
  }

  Future<void> _handleRecordSettled() async {
    setState(() => _isProcessing = true);
    final controller = ref.read(settlementControllerProvider.notifier);

    final utrText = _utrController.text.trim();
    final txnText = _txnIdController.text.trim();

    await controller.recordSettlementAsSettled(
      settlementId: widget.settlement.id,
      merchantId: widget.settlement.merchantId,
      utr: utrText.isNotEmpty ? utrText : null,
      transactionId: txnText.isNotEmpty ? txnText : null,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment recorded. Dues of ${CurrencyFormatter.formatPaise(widget.settlement.amountPaise)} marked as settled.',
        ),
        backgroundColor: AppColors.settledGreen,
      ),
    );
  }

  Future<void> _handleRecordFailed() async {
    setState(() => _isProcessing = true);
    final controller = ref.read(settlementControllerProvider.notifier);

    await controller.recordSettlementAsFailed(
      settlementId: widget.settlement.id,
      merchantId: widget.settlement.merchantId,
      reason: 'User reported payment failed or cancelled',
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Settlement marked as cancelled. Outstanding dues preserved.',
        ),
      ),
    );
  }

  Future<void> _handleDecideLater() async {
    setState(() => _isProcessing = true);
    final controller = ref.read(settlementControllerProvider.notifier);

    await controller.recordSettlementAsUnknown(
      settlementId: widget.settlement.id,
      merchantId: widget.settlement.merchantId,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Settlement pending. Dues remain recorded until you confirm payment.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Record Settlement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Store',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        widget.merchantName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatPaise(widget.settlement.amountPaise),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'KhataFlow does not hold funds or verify payments automatically. Did you complete the transfer in your UPI app?',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _utrController,
              decoration: const InputDecoration(
                labelText: 'UPI Reference / UTR (Optional)',
                hintText: 'e.g. 423456789012',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _txnIdController,
              decoration: const InputDecoration(
                labelText: 'Transaction ID / Note (Optional)',
                hintText: 'e.g. T240909...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
      ),
      actions: [
        if (_isProcessing)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: _handleRecordSettled,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.settledGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Record Payment (Mark Settled)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleRecordFailed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.outstandingRed,
                        side: const BorderSide(color: AppColors.outstandingRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Payment Failed'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: _handleDecideLater,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondaryLight,
                      ),
                      child: const Text('Decide Later'),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

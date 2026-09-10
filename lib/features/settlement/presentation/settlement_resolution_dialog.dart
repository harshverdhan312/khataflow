import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../domain/settlement.dart';
import 'settlement_providers.dart';

class SettlementResolutionDialog extends ConsumerStatefulWidget {
  final Settlement settlement;
  final String merchantName;
  final String? initialUtr;
  final String? initialTxnId;
  final String? initialUpiStatus;

  static bool isShowing = false;

  const SettlementResolutionDialog({
    super.key,
    required this.settlement,
    required this.merchantName,
    this.initialUtr,
    this.initialTxnId,
    this.initialUpiStatus,
  });

  static Future<void> show(
    BuildContext context, {
    required Settlement settlement,
    required String merchantName,
    String? initialUtr,
    String? initialTxnId,
    String? initialUpiStatus,
  }) async {
    if (isShowing) return;
    isShowing = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => SettlementResolutionDialog(
          settlement: settlement,
          merchantName: merchantName,
          initialUtr: initialUtr,
          initialTxnId: initialTxnId,
          initialUpiStatus: initialUpiStatus,
        ),
      );
    } finally {
      isShowing = false;
    }
  }

  @override
  ConsumerState<SettlementResolutionDialog> createState() =>
      _SettlementResolutionDialogState();
}

class _SettlementResolutionDialogState
    extends ConsumerState<SettlementResolutionDialog> {
  late final TextEditingController _utrController;
  late final TextEditingController _txnIdController;
  bool _isProcessing = false;
  late bool _showReferenceFields;

  @override
  void initState() {
    super.initState();
    _utrController = TextEditingController(text: widget.initialUtr ?? '');
    _txnIdController = TextEditingController(text: widget.initialTxnId ?? '');
    _showReferenceFields = (widget.initialUtr != null && widget.initialUtr!.isNotEmpty) ||
        (widget.initialTxnId != null && widget.initialTxnId!.isNotEmpty);
  }

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
    final amountFormatted = CurrencyFormatter.formatPaise(widget.settlement.amountPaise);

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
              Icons.help_outline_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Did you complete the payment?',
              style: TextStyle(
                fontSize: 17,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$amountFormatted to ${widget.merchantName}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.settledGreen,
                    size: 20,
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
                      'KhataFlow does not hold funds or independently verify bank transfers. Please confirm the result from your UPI app.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Collapsible / Optional reference section
            GestureDetector(
              onTap: () {
                setState(() => _showReferenceFields = !_showReferenceFields);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _showReferenceFields
                          ? Icons.remove_circle_outline
                          : Icons.add_circle_outline,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showReferenceFields
                          ? 'Hide payment reference'
                          : '+ Add payment reference (optional)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showReferenceFields) ...[
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
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
                  'Yes, Payment Completed',
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

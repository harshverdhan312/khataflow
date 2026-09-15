import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../merchant/domain/merchant.dart';
import 'settlement_providers.dart';

class SettlementConfirmationSheet extends ConsumerStatefulWidget {
  final Merchant merchant;
  final int outstandingPaise;
  final int purchaseCount;

  const SettlementConfirmationSheet({
    super.key,
    required this.merchant,
    required this.outstandingPaise,
    required this.purchaseCount,
  });

  static Future<void> show(
    BuildContext context, {
    required Merchant merchant,
    required int outstandingPaise,
    required int purchaseCount,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettlementConfirmationSheet(
        merchant: merchant,
        outstandingPaise: outstandingPaise,
        purchaseCount: purchaseCount,
      ),
    );
  }

  @override
  ConsumerState<SettlementConfirmationSheet> createState() =>
      _SettlementConfirmationSheetState();
}

class _SettlementConfirmationSheetState
    extends ConsumerState<SettlementConfirmationSheet> {
  final TextEditingController _referenceController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _handleRecordSettlement() async {
    setState(() => _isProcessing = true);

    final controller = ref.read(settlementControllerProvider.notifier);
    final refText = _referenceController.text.trim();

    final resultState = await controller.recordSettlement(
      merchantId: widget.merchant.id,
      paymentReference: refText.isNotEmpty ? refText : null,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (resultState.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultState.errorMessage!),
          backgroundColor: AppColors.outstandingRed,
        ),
      );
      return;
    }

    final activeSettlement = resultState.activeSettlement;
    if (activeSettlement != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close bottom sheet
      }

      final formattedAmount = CurrencyFormatter.formatPaise(widget.outstandingPaise);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settlement recorded. Dues of $formattedAmount marked as settled.'),
          backgroundColor: AppColors.settledGreen,
        ),
      );

      try {
        context.push('/receipt/${activeSettlement.id}');
      } catch (_) {
        // Ignored if GoRouter is not available in testing environment
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.settledGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.settledGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Settlement',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mark outstanding dues as settled outside KhataFlow',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
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
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          widget.merchant.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (widget.merchant.upiVpa.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Store UPI ID',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                widget.merchant.upiVpa,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: widget.merchant.upiVpa));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied ${widget.merchant.upiVpa} to clipboard'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(2.0),
                                  child: Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Purchases Cleared',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          '${widget.purchaseCount} item(s)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Settlement Amount',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatPaise(widget.outstandingPaise),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.settledGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 14),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Payment Reference (Optional)',
                  hintText: 'e.g. UTR / transaction reference',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This is a local ledger record. KhataFlow does not hold, process, or independently verify funds.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryLight.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isProcessing ? null : _handleRecordSettlement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.settledGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Record Settlement — ${CurrencyFormatter.formatPaise(widget.outstandingPaise)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

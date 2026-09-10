import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/upi_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../merchant/domain/merchant.dart';
import 'settlement_providers.dart';

import 'settlement_resolution_dialog.dart';

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
  bool _isLaunching = false;

  Future<void> _handleProceedToPay() async {
    setState(() => _isLaunching = true);

    final controller = ref.read(settlementControllerProvider.notifier);
    final resultState = await controller.initiateAndLaunchPayment(
      merchantId: widget.merchant.id,
      merchantName: widget.merchant.name,
      merchantVpa: widget.merchant.upiVpa,
    );

    if (!mounted) return;
    setState(() => _isLaunching = false);

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
    final launchResult = resultState.launchResult;

    if (activeSettlement != null) {
      Navigator.of(context).pop(); // Close confirmation bottom sheet

      if (launchResult?.status == UpiLaunchStatus.noAppInstalled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No compatible UPI app found. Dues preserved.'),
            backgroundColor: AppColors.outstandingRed,
          ),
        );
        return;
      }

      if (launchResult?.status == UpiLaunchStatus.launchFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(launchResult?.statusMessage ?? 'Failed to open UPI app'),
            backgroundColor: AppColors.outstandingRed,
          ),
        );
        return;
      }

      // Show resolution dialog with opportunistically captured UPI response details
      SettlementResolutionDialog.show(
        context,
        settlement: activeSettlement,
        merchantName: widget.merchant.name,
        initialUtr: launchResult?.approvalRefNo,
        initialTxnId: launchResult?.txnId,
        initialUpiStatus: launchResult?.upiStatus,
      );
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
                    Icons.account_balance_wallet_outlined,
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
                        'Clear Outstanding Dues',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Direct settlement via your UPI app',
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
                        'Pay To Store',
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Store UPI VPA',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        widget.merchant.upiVpa,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
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
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No transaction fees. KhataFlow will open your installed UPI app directly.',
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
              onPressed: _isLaunching ? null : _handleProceedToPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.settledGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isLaunching
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Open UPI App — ${CurrencyFormatter.formatPaise(widget.outstandingPaise)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

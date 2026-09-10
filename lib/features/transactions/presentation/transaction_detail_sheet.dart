import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../merchant/domain/merchant.dart';
import '../../settlement/domain/settlement.dart';
import '../../settlement/domain/settlement_status.dart';
import '../../settlement/presentation/settlement_resolution_dialog.dart';

class TransactionDetailSheet extends ConsumerWidget {
  final Settlement settlement;
  final Merchant? merchant;

  const TransactionDetailSheet({
    super.key,
    required this.settlement,
    this.merchant,
  });

  static Future<void> show(
    BuildContext context, {
    required Settlement settlement,
    Merchant? merchant,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(
        settlement: settlement,
        merchant: merchant,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantName = merchant?.name ?? 'Unknown Store';
    final amountFormatted = CurrencyFormatter.formatPaise(settlement.amountPaise);
    final dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(settlement.initiatedAt);
    final status = settlement.status;

    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case SettlementStatus.settled:
        statusColor = AppColors.settledGreen;
        statusBgColor = AppColors.settledGreen.withValues(alpha: 0.12);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Settled';
        break;
      case SettlementStatus.failed:
        statusColor = AppColors.outstandingRed;
        statusBgColor = AppColors.outstandingRed.withValues(alpha: 0.12);
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Failed';
        break;
      case SettlementStatus.unknown:
        statusColor = Colors.orange.shade800;
        statusBgColor = Colors.orange.withValues(alpha: 0.12);
        statusIcon = Icons.help_outline_rounded;
        statusLabel = 'Pending Confirmation';
        break;
      case SettlementStatus.upiLaunched:
        statusColor = Colors.amber.shade800;
        statusBgColor = Colors.amber.withValues(alpha: 0.15);
        statusIcon = Icons.open_in_new_rounded;
        statusLabel = 'UPI Launched';
        break;
      case SettlementStatus.initiated:
        statusColor = Colors.blue.shade700;
        statusBgColor = Colors.blue.withValues(alpha: 0.12);
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = 'Initiated';
        break;
    }

    final isUnresolved = status == SettlementStatus.initiated ||
        status == SettlementStatus.upiLaunched ||
        status == SettlementStatus.unknown;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header with status icon & amount
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 36),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                amountFormatted,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Detail items
            _buildDetailRow(
              icon: Icons.store_rounded,
              label: 'Merchant / Store',
              value: merchantName,
              subValue: merchant?.upiVpa,
            ),
            const Divider(height: 24),

            _buildDetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Initiated On',
              value: dateFormatted,
            ),
            if (settlement.completedAt != null) ...[
              const Divider(height: 24),
              _buildDetailRow(
                icon: Icons.event_available_rounded,
                label: 'Completed On',
                value: DateFormat('dd MMM yyyy, hh:mm a').format(settlement.completedAt!),
              ),
            ],

            if (settlement.utr != null && settlement.utr!.isNotEmpty) ...[
              const Divider(height: 24),
              _buildDetailRow(
                icon: Icons.tag_rounded,
                label: 'UPI Reference (UTR)',
                value: settlement.utr!,
                canCopy: true,
                context: context,
              ),
            ],

            if (settlement.transactionId != null && settlement.transactionId!.isNotEmpty) ...[
              const Divider(height: 24),
              _buildDetailRow(
                icon: Icons.receipt_long_rounded,
                label: 'Transaction ID / Note',
                value: settlement.transactionId!,
                canCopy: true,
                context: context,
              ),
            ],

            if (settlement.items.isNotEmpty) ...[
              const Divider(height: 24),
              _buildDetailRow(
                icon: Icons.shopping_basket_outlined,
                label: 'Settled Purchases',
                value: '${settlement.items.length} purchases included',
              ),
            ],

            const SizedBox(height: 20),

            // Non-custodial disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: AppColors.textSecondaryDark),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'KhataFlow records customer-verified settlements locally. Transfers occur peer-to-peer via your UPI app.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryDark,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Actions
            if (status == SettlementStatus.settled) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  try {
                    context.push('/receipt/${settlement.id}');
                  } catch (_) {}
                },

                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text(
                  'View Receipt',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.settledGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (isUnresolved) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  SettlementResolutionDialog.show(
                    context,
                    settlement: settlement,
                    merchantName: merchantName,
                    initialUtr: settlement.utr,
                    initialTxnId: settlement.transactionId,
                  );
                },
                icon: const Icon(Icons.rate_review_rounded, size: 18),
                label: const Text(
                  'Resolve Payment Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );

  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    bool canCopy = false,
    BuildContext? context,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondaryLight),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              if (subValue != null && subValue.isNotEmpty)
                Text(
                  subValue,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
            ],
          ),
        ),
        if (canCopy && context != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: AppColors.primary,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied $value to clipboard'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
      ],
    );
  }
}

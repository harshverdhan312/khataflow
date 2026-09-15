import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../settlement/domain/settlement_status.dart';
import 'transaction_detail_sheet.dart';
import 'transactions_providers.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(allTransactionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Transactions Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Payments and settlements you clear will be recorded here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = transactions[index];
              final s = item.settlement;
              final merchantName = item.merchant?.name ?? 'Unknown Store';
              final amountFormatted = CurrencyFormatter.formatPaise(s.amountPaise);
              final dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(s.initiatedAt);

              Color statusColor;
              Color statusBgColor;
              String statusLabel;
              IconData statusIcon;

              switch (s.status) {
                case SettlementStatus.settled:
                  statusColor = AppColors.settledGreen;
                  statusBgColor = AppColors.settledGreen.withValues(alpha: 0.1);
                  statusLabel = 'Settled';
                  statusIcon = Icons.check_circle;
                  break;
                case SettlementStatus.failed:
                  statusColor = AppColors.outstandingRed;
                  statusBgColor = AppColors.outstandingRed.withValues(alpha: 0.1);
                  statusLabel = 'Failed';
                  statusIcon = Icons.cancel;
                  break;
                case SettlementStatus.unknown:
                  statusColor = AppColors.pendingAmber;
                  statusBgColor = AppColors.pendingAmber.withValues(alpha: 0.15);
                  statusLabel = 'Pending';
                  statusIcon = Icons.help_outline;
                  break;
                case SettlementStatus.initiated:
                  statusColor = AppColors.primary;
                  statusBgColor = AppColors.primary.withValues(alpha: 0.15);
                  statusLabel = 'Initiated';
                  statusIcon = Icons.hourglass_top;
                  break;
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.borderDark),
                ),
                color: AppColors.cardDark,
                child: InkWell(
                  onTap: () => TransactionDetailSheet.show(
                    context,
                    settlement: s,
                    merchant: item.merchant,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Avatar / Store Icon
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            merchantName.isNotEmpty ? merchantName[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Merchant name & date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                merchantName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.textPrimaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                dateFormatted,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusBgColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(statusIcon, size: 12, color: statusColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusLabel,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (s.utr != null && s.utr!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      'Ref: ${s.utr}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Amount & Chevron
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amountFormatted,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: s.status == SettlementStatus.settled
                                    ? AppColors.settledGreen
                                    : AppColors.textPrimaryDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.textSecondaryDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },

          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Failed to load transactions: $err'),
        ),
      ),
    );
  }
}

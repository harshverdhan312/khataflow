import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../merchant/domain/merchant.dart';
import '../../merchant/presentation/merchant_providers.dart';
import '../domain/purchase.dart';
import 'add_purchase_sheet.dart';
import 'ledger_providers.dart';

class LedgerScreen extends ConsumerWidget {
  final String merchantId;

  const LedgerScreen({
    super.key,
    required this.merchantId,
  });

  Future<void> _confirmDeactivation(BuildContext context, WidgetRef ref, Merchant merchant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Store Tab?'),
        content: Text(
          'Are you sure you want to deactivate ${merchant.name}\'s tab? Historical records will be preserved, but the store will no longer appear on your active dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.outstandingRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(addMerchantControllerProvider.notifier)
          .deactivateMerchant(merchant.id);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${merchant.name} tab deactivated'),
            ),
          );
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to deactivate tab'),
              backgroundColor: AppColors.outstandingRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantAsync = ref.watch(merchantDetailProvider(merchantId));
    final purchasesAsync = ref.watch(merchantPurchasesStreamProvider(merchantId));
    final outstandingAsync = ref.watch(merchantOutstandingStreamProvider(merchantId));

    return merchantAsync.when(
      data: (merchant) {
        if (merchant == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Store Ledger')),
            body: const Center(child: Text('Store not found')),
          );
        }

        final outstandingPaise = outstandingAsync.value ?? 0;
        final hasOutstanding = outstandingPaise > 0;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              merchant.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'deactivate') {
                    _confirmDeactivation(context, ref, merchant);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 20, color: AppColors.outstandingRed),
                        SizedBox(width: 8),
                        Text('Deactivate Tab', style: TextStyle(color: AppColors.outstandingRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Merchant Header & Outstanding Banner
              _buildHeader(merchant, outstandingPaise, hasOutstanding),

              // Purchases List
              Expanded(
                child: purchasesAsync.when(
                  data: (purchases) {
                    if (purchases.isEmpty) {
                      return _buildEmptyPurchasesState(context, merchant);
                    }
                    return _buildPurchasesList(purchases);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading ledger: $err')),
                ),
              ),

              // Bottom Action Bar
              _buildBottomActionBar(context, merchant, outstandingPaise, hasOutstanding),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Store Ledger')),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHeader(Merchant merchant, int outstandingPaise, bool hasOutstanding) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        border: const Border(
          bottom: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      merchant.category.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (merchant.phone != null) ...[
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: AppColors.textSecondaryLight),
                        const SizedBox(width: 4),
                        Text(
                          merchant.phone!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.verified, size: 14, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    merchant.upiVpa,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT OUTSTANDING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondaryLight,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dues to settle with merchant',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              Text(
                CurrencyFormatter.formatPaise(outstandingPaise),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: hasOutstanding
                      ? AppColors.outstandingRed
                      : AppColors.settledGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasesList(List<Purchase> purchases) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: purchases.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final purchase = purchases[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchase.note,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          purchase.purchaseDate.toFormattedDate(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        if (purchase.category != null && purchase.category!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.borderLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              purchase.category!,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                CurrencyFormatter.formatPaise(purchase.amountPaise),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyPurchasesState(BuildContext context, Merchant merchant) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No purchases on this tab yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Record items bought on credit from ${merchant.name}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    Merchant merchant,
    int outstandingPaise,
    bool hasOutstanding,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        border: const Border(
          top: BorderSide(color: AppColors.borderLight),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: OutlinedButton.icon(
                onPressed: () {
                  AddPurchaseSheet.show(
                    context,
                    merchantId: merchant.id,
                    merchantName: merchant.name,
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Purchase'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: ElevatedButton.icon(
                onPressed: hasOutstanding
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Native UPI settlement for ${CurrencyFormatter.formatPaise(outstandingPaise)} to ${merchant.upiVpa} will be enabled in Milestone 3.',
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.payment),
                label: Text(
                  hasOutstanding
                      ? 'Clear Dues — ${CurrencyFormatter.formatPaise(outstandingPaise)}'
                      : 'All Cleared',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.settledGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.borderLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

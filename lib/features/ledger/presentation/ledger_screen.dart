import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../merchant/domain/merchant.dart';
import '../../merchant/presentation/merchant_providers.dart';
import '../../settlement/domain/settlement.dart';
import '../../settlement/domain/settlement_status.dart';
import '../../settlement/presentation/settlement_confirmation_sheet.dart';
import '../../settlement/presentation/settlement_providers.dart';
import '../../settlement/presentation/settlement_resolution_dialog.dart';
import '../domain/purchase.dart';
import 'add_purchase_sheet.dart';
import 'ledger_providers.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  final String merchantId;

  const LedgerScreen({
    super.key,
    required this.merchantId,
  });

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen>
    with WidgetsBindingObserver {
  bool _isResolutionDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // If a native UPI intent is actively awaiting ActivityResult over MethodChannel,
      // allow the authoritative MethodChannel callback to handle the dialog with metadata.
      final isLaunchInFlight = ref.read(settlementControllerProvider).isLoading;
      if (!isLaunchInFlight) {
        _checkAndPromptUnresolvedSettlement();
      }
    }
  }

  Future<void> _checkAndPromptUnresolvedSettlement() async {
    if (!mounted || _isResolutionDialogShowing) return;
    final repo = ref.read(settlementRepositoryProvider);
    final unresolved = await repo.getUnresolvedSettlements(merchantId: widget.merchantId);
    if (!mounted || _isResolutionDialogShowing || unresolved.isEmpty) return;

    final merchant = ref.read(merchantDetailProvider(widget.merchantId)).value;
    if (merchant == null) return;

    final launchResult = ref.read(settlementControllerProvider).launchResult;

    _isResolutionDialogShowing = true;
    await SettlementResolutionDialog.show(
      context,
      settlement: unresolved.first,
      merchantName: merchant.name,
      initialUtr: launchResult?.approvalRefNo,
      initialTxnId: launchResult?.txnId,
      initialUpiStatus: launchResult?.upiStatus,
    );
    if (mounted) {
      _isResolutionDialogShowing = false;
    }
  }

  Future<void> _showManualResolutionDialog(Settlement settlement, String merchantName) async {
    if (_isResolutionDialogShowing) return;
    final launchResult = ref.read(settlementControllerProvider).launchResult;

    _isResolutionDialogShowing = true;
    await SettlementResolutionDialog.show(
      context,
      settlement: settlement,
      merchantName: merchantName,
      initialUtr: launchResult?.approvalRefNo,
      initialTxnId: launchResult?.txnId,
      initialUpiStatus: launchResult?.upiStatus,
    );
    if (mounted) {
      _isResolutionDialogShowing = false;
    }
  }

  Future<void> _confirmDeactivation(BuildContext context, Merchant merchant) async {
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
          ref.invalidate(merchantDetailProvider(widget.merchantId));
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

  Future<void> _confirmReactivation(BuildContext context, Merchant merchant) async {
    final success = await ref
        .read(addMerchantControllerProvider.notifier)
        .reactivateMerchant(merchant.id);
    if (context.mounted) {
      if (success) {
        ref.invalidate(merchantDetailProvider(widget.merchantId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${merchant.name} tab reactivated'),
            backgroundColor: AppColors.settledGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reactivate tab'),
            backgroundColor: AppColors.outstandingRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchantAsync = ref.watch(merchantDetailProvider(widget.merchantId));
    final purchasesAsync = ref.watch(merchantPurchasesStreamProvider(widget.merchantId));
    final settlementsAsync = ref.watch(merchantSettlementsStreamProvider(widget.merchantId));
    final outstandingAsync = ref.watch(merchantOutstandingStreamProvider(widget.merchantId));
    final unresolvedAsync = ref.watch(unresolvedSettlementsForMerchantProvider(widget.merchantId));

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
        final purchases = purchasesAsync.value ?? [];
        final settlements = settlementsAsync.value ?? [];
        final unresolvedSettlements = unresolvedAsync.value ?? [];
        final hasUnresolved = unresolvedSettlements.isNotEmpty;
        final pendingSettlement = hasUnresolved ? unresolvedSettlements.first : null;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (!merchant.isActive)
                    const Text(
                      'Archived Store Tab',
                      style: TextStyle(fontSize: 11, color: AppColors.outstandingRed),
                    ),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      context.push('/merchant/edit/${merchant.id}');
                    } else if (value == 'deactivate') {
                      _confirmDeactivation(context, merchant);
                    } else if (value == 'reactivate') {
                      _confirmReactivation(context, merchant);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Edit Store Details'),
                        ],
                      ),
                    ),
                    if (merchant.isActive)
                      const PopupMenuItem(
                        value: 'deactivate',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 20, color: AppColors.outstandingRed),
                            SizedBox(width: 8),
                            Text('Deactivate Tab', style: TextStyle(color: AppColors.outstandingRed)),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'reactivate',
                        child: Row(
                          children: [
                            Icon(Icons.unarchive_outlined, size: 20, color: AppColors.settledGreen),
                            SizedBox(width: 8),
                            Text('Reactivate Tab', style: TextStyle(color: AppColors.settledGreen)),
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

                // Unresolved Settlement Recovery Banner
                if (pendingSettlement != null)
                  _buildUnresolvedBanner(context, merchant, pendingSettlement),

                // Tabs: Purchases vs Settlements
                Container(
                  color: AppColors.cardLight,
                  child: TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondaryLight,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Purchases (${purchases.length})',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_outlined, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Settlements (${settlements.length})',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Purchases List
                      purchasesAsync.when(
                        data: (purchasesList) {
                          if (purchasesList.isEmpty) {
                            return _buildEmptyPurchasesState(context, merchant);
                          }
                          return _buildPurchasesList(purchasesList);
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error loading ledger: $err')),
                      ),

                      // Tab 2: Settlements List
                      settlementsAsync.when(
                        data: (settlementsList) {
                          if (settlementsList.isEmpty) {
                            return _buildEmptySettlementsState(context, merchant);
                          }
                          return _buildSettlementsList(context, merchant, settlementsList);
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error loading settlements: $err')),
                      ),
                    ],
                  ),
                ),

                // Bottom Action Bar
                if (merchant.isActive)
                  _buildBottomActionBar(
                    context,
                    merchant,
                    outstandingPaise,
                    hasOutstanding,
                    purchases.length,
                    pendingSettlement,
                  ),
              ],
            ),
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
      decoration: const BoxDecoration(
        color: AppColors.cardLight,
        border: Border(
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
        final isSettled = purchase.isSettled;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSettled
                      ? AppColors.settledGreen.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSettled ? Icons.check_circle_outline : Icons.shopping_bag_outlined,
                  size: 20,
                  color: isSettled ? AppColors.settledGreen : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            purchase.note,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: isSettled ? TextDecoration.none : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSettled ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSettled ? Colors.green.shade300 : Colors.orange.shade300,
                            ),
                          ),
                          child: Text(
                            isSettled ? 'Settled' : 'Outstanding',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSettled ? Colors.green.shade800 : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isSettled ? AppColors.textSecondaryLight : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettlementsList(
    BuildContext context,
    Merchant merchant,
    List<Settlement> settlements,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: settlements.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final settlement = settlements[index];
        final isSettled = settlement.status == SettlementStatus.settled;
        final isUnresolved = settlement.status.isUnresolved;
        final isFailed = settlement.status == SettlementStatus.failed;

        Color badgeBgColor;
        Color badgeTextColor;
        String statusLabel;

        if (isSettled) {
          badgeBgColor = Colors.green.shade50;
          badgeTextColor = Colors.green.shade800;
          statusLabel = 'SETTLED';
        } else if (isFailed) {
          badgeBgColor = Colors.red.shade50;
          badgeTextColor = Colors.red.shade800;
          statusLabel = 'FAILED';
        } else if (settlement.status == SettlementStatus.upiLaunched) {
          badgeBgColor = Colors.amber.shade50;
          badgeTextColor = Colors.amber.shade900;
          statusLabel = 'UPI LAUNCHED';
        } else if (settlement.status == SettlementStatus.initiated) {
          badgeBgColor = Colors.blue.shade50;
          badgeTextColor = Colors.blue.shade800;
          statusLabel = 'INITIATED';
        } else {
          badgeBgColor = Colors.amber.shade50;
          badgeTextColor = Colors.amber.shade900;
          statusLabel = 'UNKNOWN';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: badgeBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isSettled
                          ? Icons.check_circle_outline
                          : (isFailed ? Icons.error_outline : Icons.pending_outlined),
                      size: 20,
                      color: badgeTextColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              settlement.initiatedAt.toFormattedDate(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeBgColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: badgeTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              settlement.completedAt != null
                                  ? 'Settled at ${settlement.completedAt!.toFormattedDateTime()}'
                                  : 'Initiated at ${settlement.initiatedAt.toFormattedDateTime()}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            if (settlement.items.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '•  ${settlement.items.length} ${settlement.items.length == 1 ? 'item' : 'items'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (settlement.utr != null && settlement.utr!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'UTR: ${settlement.utr}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                        if (settlement.transactionId != null &&
                            settlement.transactionId!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Txn ID: ${settlement.transactionId}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.formatPaise(settlement.amountPaise),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isSettled ? AppColors.settledGreen : AppColors.textPrimaryLight,
                        ),
                      ),
                      if (isUnresolved || isFailed) ...[
                        const SizedBox(height: 6),
                        ElevatedButton(
                          onPressed: () {
                            _showManualResolutionDialog(settlement, merchant.name);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFailed ? Colors.red.shade700 : Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(60, 28),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('Resolve'),
                        ),
                      ],
                    ],
                  ),
                ],
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

  Widget _buildEmptySettlementsState(BuildContext context, Merchant merchant) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.payments_outlined,
              size: 56,
              color: AppColors.settledGreen.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No settlements recorded yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Once you clear dues via UPI with ${merchant.name}, settled and pending payment records will appear here.',
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

  Widget _buildUnresolvedBanner(BuildContext context, Merchant merchant, Settlement settlement) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.pending_actions_outlined, size: 20, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Settlement: ${CurrencyFormatter.formatPaise(settlement.amountPaise)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Initiated ${settlement.initiatedAt.toFormattedDateTime()}. Please confirm payment outcome.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              _showManualResolutionDialog(
                settlement,
                merchant.name,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(60, 32),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    Merchant merchant,
    int outstandingPaise,
    bool hasOutstanding,
    int purchaseCount,
    Settlement? pendingSettlement,
  ) {
    final hasPendingSettlement = pendingSettlement != null;

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
                onPressed: hasPendingSettlement
                    ? () {
                        _showManualResolutionDialog(
                          pendingSettlement,
                          merchant.name,
                        );
                      }
                    : (hasOutstanding
                        ? () {
                            SettlementConfirmationSheet.show(
                              context,
                              merchant: merchant,
                              outstandingPaise: outstandingPaise,
                              purchaseCount: purchaseCount,
                            );
                          }
                        : null),
                icon: Icon(hasPendingSettlement ? Icons.pending : Icons.payment),
                label: Text(
                  hasPendingSettlement
                      ? 'Resolve Pending'
                      : (hasOutstanding
                          ? 'Clear Dues — ${CurrencyFormatter.formatPaise(outstandingPaise)}'
                          : 'All Cleared'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasPendingSettlement
                      ? Colors.amber.shade800
                      : AppColors.settledGreen,
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

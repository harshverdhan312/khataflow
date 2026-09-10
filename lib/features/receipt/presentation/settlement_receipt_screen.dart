import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../domain/settlement_receipt.dart';
import '../domain/settlement_statement_formatter.dart';
import 'receipt_providers.dart';

class SettlementReceiptScreen extends ConsumerStatefulWidget {
  final String settlementId;

  const SettlementReceiptScreen({
    super.key,
    required this.settlementId,
  });

  @override
  ConsumerState<SettlementReceiptScreen> createState() => _SettlementReceiptScreenState();
}

class _SettlementReceiptScreenState extends ConsumerState<SettlementReceiptScreen> {
  bool _isSharingText = false;
  bool _isSharingPdf = false;

  bool get _isSharing => _isSharingText || _isSharingPdf;

  @override
  Widget build(BuildContext context) {
    final receiptAsync = ref.watch(settlementReceiptProvider(widget.settlementId));

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        title: const Text(
          'Settlement Receipt',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
        ),
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.surfaceDark,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimaryDark),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          receiptAsync.when(
            data: (receipt) {
              if (receipt == null) return const SizedBox.shrink();
              return IconButton(
                icon: _isSharingText
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.share_rounded, color: AppColors.textPrimaryDark),
                tooltip: 'Share Statement',
                onPressed: _isSharing ? null : () => _handleShareStatement(receipt),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: receiptAsync.when(
        data: (receipt) {
          if (receipt == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Receipt Not Available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Receipts are only generated for successfully settled payments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _buildReceiptView(context, receipt);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error loading receipt: $err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.outstandingRed),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptView(BuildContext context, SettlementReceipt receipt) {
    final amountFormatted = CurrencyFormatter.formatPaise(receipt.amountPaise);
    final dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(receipt.settlementDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Receipt Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.borderDark),
            ),
            color: AppColors.cardDark,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Success Badge Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.settledGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.settledGreen,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Payment Settled',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.settledGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      amountFormatted,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: AppColors.dividerDark),
                  const SizedBox(height: 16),

                  // Paid To Row
                  _buildMetaRow(
                    label: 'Paid to',
                    value: receipt.merchantName,
                  ),
                  const SizedBox(height: 14),

                  // Date & Time Row
                  _buildMetaRow(
                    label: 'Date & Time',
                    value: dateFormatted,
                  ),

                  // UPI ID Row
                  if (receipt.merchantUpiVpa.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildMetaRow(
                      label: 'UPI ID',
                      value: receipt.merchantUpiVpa,
                      canCopy: true,
                      context: context,
                    ),
                  ],

                  // Payment Reference / UTR
                  if (receipt.utr != null && receipt.utr!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildMetaRow(
                      label: 'Payment Reference (UTR)',
                      value: receipt.utr!,
                      canCopy: true,
                      context: context,
                    ),
                  ],

                  // Transaction ID
                  if (receipt.transactionId != null && receipt.transactionId!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildMetaRow(
                      label: 'Transaction ID',
                      value: receipt.transactionId!,
                      canCopy: true,
                      context: context,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Items Settled Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.borderDark),
            ),
            color: AppColors.cardDark,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Items Settled',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${receipt.items.length} ${receipt.items.length == 1 ? 'item' : 'items'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.dividerDark),
                  const SizedBox(height: 12),

                  if (receipt.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Direct settlement with merchant.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryDark,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...receipt.items.map((item) {
                      final itemDate = DateFormat('dd MMM yyyy').format(item.purchaseDate);
                      final itemAmount = CurrencyFormatter.formatPaise(item.amountPaise);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                size: 16,
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.note.isNotEmpty ? item.note : 'Purchase',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    itemDate,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              itemAmount,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.dividerDark),
                  const SizedBox(height: 14),

                  // Total Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Settled',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatPaise(receipt.totalSettledPaise),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.settledGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Non-custodial local ledger note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: AppColors.textSecondaryDark,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This receipt represents a customer-recorded settlement in your local KhataFlow credit ledger.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryDark,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSharing ? null : () => _handleShareStatement(receipt),
                  icon: _isSharingText
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.share_rounded, size: 16),
                  label: const Text(
                    'Share Text',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSharing ? null : () => _handleSharePdf(receipt),
                  icon: _isSharingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text(
                    'Share PDF',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Done Button
          ElevatedButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/ledger/${receipt.merchantId}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShareStatement(SettlementReceipt receipt) async {
    if (_isSharing) return;
    setState(() => _isSharingText = true);

    try {
      final statementText = SettlementStatementFormatter.format(receipt);
      final shareService = ref.read(receiptShareServiceProvider);
      await shareService.shareGenericText(
        text: statementText,
        subject: 'KhataFlow Settlement Statement - ${receipt.merchantName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share statement: $e'),
            backgroundColor: AppColors.outstandingRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingText = false);
      }
    }
  }

  Future<void> _handleSharePdf(SettlementReceipt receipt) async {
    if (_isSharing) return;
    setState(() => _isSharingPdf = true);

    try {
      final pdfService = ref.read(settlementPdfServiceProvider);
      final file = await pdfService.generateAndSavePdf(receipt);
      final shareService = ref.read(receiptShareServiceProvider);
      await shareService.shareFile(
        filePath: file.path,
        mimeType: 'application/pdf',
        subject: 'KhataFlow Settlement Statement - ${receipt.merchantName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate or share PDF: $e'),
            backgroundColor: AppColors.outstandingRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingPdf = false);
      }
    }
  }

  Widget _buildMetaRow({
    required String label,
    required String value,
    String? subValue,
    bool canCopy = false,
    BuildContext? context,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              if (subValue != null && subValue.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subValue,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (canCopy && context != null)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied $value to clipboard'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.copy_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

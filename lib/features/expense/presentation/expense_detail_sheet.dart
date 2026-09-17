import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../domain/expense.dart';
import 'expense_providers.dart';

class ExpenseDetailSheet extends ConsumerWidget {
  final Expense expense;

  const ExpenseDetailSheet({
    super.key,
    required this.expense,
  });

  static Future<void> show(
    BuildContext context, {
    required Expense expense,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseDetailSheet(
        expense: expense,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text(
          'Delete Expense?',
          style: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.outstandingRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await ref.read(addExpenseControllerProvider.notifier).delete(expense.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        if (success) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Expense deleted'),
              backgroundColor: AppColors.settledGreen,
            ),
          );
        } else {
          final error = ref.read(addExpenseControllerProvider).errorMessage;
          messenger.showSnackBar(
            SnackBar(
              content: Text(error ?? 'Failed to delete expense'),
              backgroundColor: AppColors.outstandingRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountFormatted = CurrencyFormatter.formatPaise(expense.amountPaise);
    final dateFormatted = expense.expenseDate.toFormattedDate();
    final timeFormatted = expense.expenseDate.toTimeDisplay();

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

            // Header with category icon & formatted amount
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
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
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  expense.category.displayName,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Detail items
            _buildDetailRow(
              icon: Icons.category_outlined,
              label: 'Category',
              value: expense.category.displayName,
            ),
            const Divider(height: 24, color: AppColors.borderDark),

            _buildDetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Expense Date',
              value: '$dateFormatted at $timeFormatted',
            ),

            if (expense.note != null && expense.note!.isNotEmpty) ...[
              const Divider(height: 24, color: AppColors.borderDark),
              _buildDetailRow(
                icon: Icons.notes_rounded,
                label: 'Note',
                value: expense.note!,
              ),
            ],

            const Divider(height: 24, color: AppColors.borderDark),
            _buildDetailRow(
              icon: Icons.cloud_sync_outlined,
              label: 'Sync Status',
              value: expense.syncStatus.name.toUpperCase(),
            ),

            const SizedBox(height: 24),

            // Edit button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/expense/edit/${expense.id}');
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(
                'Edit Expense',
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

            // Delete button
            OutlinedButton.icon(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.outstandingRed),
              label: const Text(
                'Delete Expense',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.outstandingRed,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.outstandingRed),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Close button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.textSecondaryDark),
              ),
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
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondaryDark),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

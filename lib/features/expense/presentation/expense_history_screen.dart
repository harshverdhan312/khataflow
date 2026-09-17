import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import 'expense_detail_sheet.dart';
import 'expense_providers.dart';

class ExpenseHistoryScreen extends ConsumerWidget {
  const ExpenseHistoryScreen({super.key});

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.transport:
        return Icons.directions_car_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.bills:
        return Icons.receipt_rounded;
      case ExpenseCategory.entertainment:
        return Icons.movie_rounded;
      case ExpenseCategory.health:
        return Icons.local_hospital_rounded;
      case ExpenseCategory.education:
        return Icons.school_rounded;
      case ExpenseCategory.other:
        return Icons.category_rounded;
    }
  }

  Map<DateTime, List<Expense>> _groupByDate(List<Expense> expenses) {
    final grouped = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      final date = DateTime(
        expense.expenseDate.year,
        expense.expenseDate.month,
        expense.expenseDate.day,
      );
      grouped.putIfAbsent(date, () => []).add(expense);
    }
    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (date.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return date.toFormattedDate();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Expense',
            onPressed: () => context.push('/expense/add'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/expense/add'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: expensesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.outstandingRed,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load expenses',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(expensesStreamProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No expenses recorded yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add your personal expenses to track your spending locally.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/expense/add'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Expense'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final grouped = _groupByDate(expenses);
          final sortedDates = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: sortedDates.length,
            itemBuilder: (context, dateIndex) {
              final date = sortedDates[dateIndex];
              final dayExpenses = grouped[date]!;
              final headerText = _formatDateHeader(date);
              final dayTotalPaise = dayExpenses.fold<int>(0, (sum, e) => sum + e.amountPaise);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          headerText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatPaise(dayTotalPaise),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...dayExpenses.map((expense) {
                    return Card(
                      color: AppColors.cardDark,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.borderDark),
                      ),
                      child: InkWell(
                        onTap: () => ExpenseDetailSheet.show(context, expense: expense),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getCategoryIcon(expense.category),
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      expense.category.displayName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      expense.note != null && expense.note!.isNotEmpty
                                          ? expense.note!
                                          : expense.expenseDate.toTimeDisplay(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.formatPaise(expense.amountPaise),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

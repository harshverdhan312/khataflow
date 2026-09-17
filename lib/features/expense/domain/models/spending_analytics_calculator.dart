import '../expense.dart';
import '../expense_category.dart';
import 'category_spending.dart';
import 'spending_analytics.dart';

export 'category_spending.dart';
export 'spending_analytics.dart';

class SpendingAnalyticsCalculator {
  /// Pure deterministic analytics calculator.
  /// Derives [SpendingAnalytics] from a list of [Expense] records.
  ///
  /// Reference time [now] defaults to [DateTime.now()] when omitted.
  static SpendingAnalytics calculate(
    List<Expense> expenses, {
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();
    final currentPeriodStart = DateTime(referenceTime.year, referenceTime.month, 1);
    final currentPeriodEnd = DateTime(referenceTime.year, referenceTime.month + 1, 1);
    final previousPeriodStart = DateTime(referenceTime.year, referenceTime.month - 1, 1);
    final previousPeriodEnd = currentPeriodStart;

    // Filter expenses into current and previous calendar months based on expenseDate
    final currentMonthExpenses = <Expense>[];
    final previousMonthExpenses = <Expense>[];

    for (final expense in expenses) {
      final date = expense.expenseDate;
      if (!date.isBefore(currentPeriodStart) && date.isBefore(currentPeriodEnd)) {
        currentMonthExpenses.add(expense);
      } else if (!date.isBefore(previousPeriodStart) && date.isBefore(previousPeriodEnd)) {
        previousMonthExpenses.add(expense);
      }
    }

    // 1. Current & Previous Totals (Pure integer addition in paise)
    var currentMonthTotalPaise = 0;
    final categoryMap = <ExpenseCategory, int>{};

    for (final expense in currentMonthExpenses) {
      currentMonthTotalPaise += expense.amountPaise;
      categoryMap[expense.category] =
          (categoryMap[expense.category] ?? 0) + expense.amountPaise;
    }

    var previousMonthTotalPaise = 0;
    for (final expense in previousMonthExpenses) {
      previousMonthTotalPaise += expense.amountPaise;
    }

    // 2. Month-over-Month Change (Paise integer change & optional percentage)
    final monthOverMonthChangePaise = currentMonthTotalPaise - previousMonthTotalPaise;
    final double? monthOverMonthChangePercent = previousMonthTotalPaise > 0
        ? ((currentMonthTotalPaise - previousMonthTotalPaise) / previousMonthTotalPaise) * 100.0
        : null;

    // 3. Category Breakdown (Sorted: Amount desc -> Category displayName asc)
    final categoryTotals = categoryMap.entries
        .where((entry) => entry.value > 0)
        .map((entry) => CategorySpending(
              category: entry.key,
              totalAmountPaise: entry.value,
            ))
        .toList()
      ..sort((a, b) {
        final amountCmp = b.totalAmountPaise.compareTo(a.totalAmountPaise);
        if (amountCmp != 0) return amountCmp;
        return a.category.displayName.compareTo(b.category.displayName);
      });

    // 4. Top Category
    final topCategory = categoryTotals.isNotEmpty ? categoryTotals.first.category : null;

    // 5. Largest Expense (Deterministic tie-break: amount desc -> date desc -> createdAt desc -> id asc)
    Expense? largestExpense;
    if (currentMonthExpenses.isNotEmpty) {
      final sortedCurrent = List<Expense>.from(currentMonthExpenses)
        ..sort((a, b) {
          final amountCmp = b.amountPaise.compareTo(a.amountPaise);
          if (amountCmp != 0) return amountCmp;
          final dateCmp = b.expenseDate.compareTo(a.expenseDate);
          if (dateCmp != 0) return dateCmp;
          final createdCmp = b.createdAt.compareTo(a.createdAt);
          if (createdCmp != 0) return createdCmp;
          return a.id.compareTo(b.id);
        });
      largestExpense = sortedCurrent.first;
    }

    // 6. Average Expense (Deterministic nearest-integer paise rounding: (total + count/2) ~/ count)
    final int? averageExpensePaise;
    if (currentMonthExpenses.isNotEmpty) {
      final count = currentMonthExpenses.length;
      averageExpensePaise = (currentMonthTotalPaise + count ~/ 2) ~/ count;
    } else {
      averageExpensePaise = null;
    }

    // 7. Recent Expenses (Deterministic ordering: date desc -> createdAt desc -> id asc, capped at 5)
    final recentExpenses = List<Expense>.from(expenses)
      ..sort((a, b) {
        final dateCmp = b.expenseDate.compareTo(a.expenseDate);
        if (dateCmp != 0) return dateCmp;
        final createdCmp = b.createdAt.compareTo(a.createdAt);
        if (createdCmp != 0) return createdCmp;
        return a.id.compareTo(b.id);
      });

    return SpendingAnalytics(
      currentPeriodStart: currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd,
      previousPeriodStart: previousPeriodStart,
      previousPeriodEnd: previousPeriodEnd,
      currentMonthTotalPaise: currentMonthTotalPaise,
      previousMonthTotalPaise: previousMonthTotalPaise,
      monthOverMonthChangePaise: monthOverMonthChangePaise,
      monthOverMonthChangePercent: monthOverMonthChangePercent,
      currentMonthExpenseCount: currentMonthExpenses.length,
      previousMonthExpenseCount: previousMonthExpenses.length,
      categoryTotals: categoryTotals,
      topCategory: topCategory,
      largestExpense: largestExpense,
      averageExpensePaise: averageExpensePaise,
      recentExpenses: recentExpenses.take(5).toList(),
    );
  }
}

/// Convenience top-level function for [SpendingAnalyticsCalculator.calculate].
SpendingAnalytics deriveSpendingAnalytics(
  List<Expense> expenses, {
  DateTime? now,
}) =>
    SpendingAnalyticsCalculator.calculate(expenses, now: now);

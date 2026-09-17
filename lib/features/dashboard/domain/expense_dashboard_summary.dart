import '../../expense/domain/expense.dart';
import '../../expense/domain/expense_category.dart';
import '../../expense/domain/models/category_spending.dart';

export '../../expense/domain/models/category_spending.dart';

class ExpenseDashboardSummary {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalAmountPaise;
  final int currentMonthExpenseCount;
  final List<CategorySpending> categoryBreakdown;
  final List<Expense> recentExpenses;

  const ExpenseDashboardSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.totalAmountPaise,
    required this.currentMonthExpenseCount,
    required this.categoryBreakdown,
    required this.recentExpenses,
  });

  bool get hasCurrentMonthExpenses => currentMonthExpenseCount > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseDashboardSummary &&
          runtimeType == other.runtimeType &&
          periodStart == other.periodStart &&
          periodEnd == other.periodEnd &&
          totalAmountPaise == other.totalAmountPaise &&
          currentMonthExpenseCount == other.currentMonthExpenseCount;

  @override
  int get hashCode => Object.hash(
        periodStart,
        periodEnd,
        totalAmountPaise,
        currentMonthExpenseCount,
      );
}

ExpenseDashboardSummary deriveExpenseDashboardSummary(
  List<Expense> expenses, [
  DateTime? now,
]) {
  final referenceTime = now ?? DateTime.now();
  final monthStart = DateTime(referenceTime.year, referenceTime.month, 1);
  final monthEnd = DateTime(referenceTime.year, referenceTime.month + 1, 1);

  // Filter current calendar month expenses based on business timestamp (expenseDate)
  final currentMonthExpenses = expenses.where((e) {
    return !e.expenseDate.isBefore(monthStart) && e.expenseDate.isBefore(monthEnd);
  }).toList();

  var totalAmountPaise = 0;
  final categoryMap = <ExpenseCategory, int>{};

  for (final expense in currentMonthExpenses) {
    totalAmountPaise += expense.amountPaise;
    categoryMap[expense.category] = (categoryMap[expense.category] ?? 0) + expense.amountPaise;
  }

  // Filter out zero spending and sort: highest spending first, secondary sort by category name
  final categoryBreakdown = categoryMap.entries
      .where((entry) => entry.value > 0)
      .map((entry) => CategorySpending(
            category: entry.key,
            totalAmountPaise: entry.value,
          ))
      .toList()
    ..sort((a, b) {
      final amountComparison = b.totalAmountPaise.compareTo(a.totalAmountPaise);
      if (amountComparison != 0) return amountComparison;
      return a.category.displayName.compareTo(b.category.displayName);
    });

  // Recent expenses preview capped at 5
  final recentExpenses = expenses.take(5).toList();

  return ExpenseDashboardSummary(
    periodStart: monthStart,
    periodEnd: monthEnd,
    totalAmountPaise: totalAmountPaise,
    currentMonthExpenseCount: currentMonthExpenses.length,
    categoryBreakdown: categoryBreakdown,
    recentExpenses: recentExpenses,
  );
}

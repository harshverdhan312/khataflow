import '../expense.dart';
import '../expense_category.dart';
import 'category_spending.dart';

class SpendingAnalytics {
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime previousPeriodStart;
  final DateTime previousPeriodEnd;
  final int currentMonthTotalPaise;
  final int previousMonthTotalPaise;
  final int monthOverMonthChangePaise;
  final double? monthOverMonthChangePercent;
  final int currentMonthExpenseCount;
  final int previousMonthExpenseCount;
  final List<CategorySpending> categoryTotals;
  final ExpenseCategory? topCategory;
  final Expense? largestExpense;
  final int? averageExpensePaise;
  final List<Expense> recentExpenses;

  const SpendingAnalytics({
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.previousPeriodStart,
    required this.previousPeriodEnd,
    required this.currentMonthTotalPaise,
    required this.previousMonthTotalPaise,
    required this.monthOverMonthChangePaise,
    this.monthOverMonthChangePercent,
    required this.currentMonthExpenseCount,
    required this.previousMonthExpenseCount,
    required this.categoryTotals,
    this.topCategory,
    this.largestExpense,
    this.averageExpensePaise,
    required this.recentExpenses,
  });

  bool get hasCurrentMonthExpenses => currentMonthExpenseCount > 0;
  bool get hasPreviousMonthExpenses => previousMonthExpenseCount > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpendingAnalytics &&
          runtimeType == other.runtimeType &&
          currentPeriodStart == other.currentPeriodStart &&
          currentPeriodEnd == other.currentPeriodEnd &&
          previousPeriodStart == other.previousPeriodStart &&
          previousPeriodEnd == other.previousPeriodEnd &&
          currentMonthTotalPaise == other.currentMonthTotalPaise &&
          previousMonthTotalPaise == other.previousMonthTotalPaise &&
          monthOverMonthChangePaise == other.monthOverMonthChangePaise &&
          monthOverMonthChangePercent == other.monthOverMonthChangePercent &&
          currentMonthExpenseCount == other.currentMonthExpenseCount &&
          previousMonthExpenseCount == other.previousMonthExpenseCount &&
          topCategory == other.topCategory &&
          largestExpense == other.largestExpense &&
          averageExpensePaise == other.averageExpensePaise;

  @override
  int get hashCode => Object.hash(
        currentPeriodStart,
        currentPeriodEnd,
        previousPeriodStart,
        previousPeriodEnd,
        currentMonthTotalPaise,
        previousMonthTotalPaise,
        monthOverMonthChangePaise,
        monthOverMonthChangePercent,
        currentMonthExpenseCount,
        previousMonthExpenseCount,
        topCategory,
        largestExpense,
        averageExpensePaise,
      );
}

import '../../../expense/domain/expense.dart';
import '../../../expense/domain/expense_category.dart';
import '../../../expense/domain/models/category_spending.dart';
import '../../../expense/domain/models/spending_insights.dart';
import '../../../expense/domain/models/spending_trends.dart';

/// Immutable bounded financial summary context provided to the AI layer.
///
/// This model deliberately encapsulates only verified, aggregated spending metrics,
/// avoiding exposing raw database records, customer identities, or unbounded history.
class AIContext {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int currentMonthTotalPaise;
  final int previousMonthTotalPaise;
  final int currentMonthExpenseCount;
  final int previousMonthExpenseCount;
  final List<CategorySpending> categoryTotals;
  final ExpenseCategory? topCategory;
  final Expense? largestExpense;
  final List<Expense> recentExpenses;
  final SpendingInsights ruleBasedInsights;
  final SpendingTrends spendingTrends;

  const AIContext({
    required this.periodStart,
    required this.periodEnd,
    required this.currentMonthTotalPaise,
    required this.previousMonthTotalPaise,
    required this.currentMonthExpenseCount,
    required this.previousMonthExpenseCount,
    required this.categoryTotals,
    this.topCategory,
    this.largestExpense,
    required this.recentExpenses,
    required this.ruleBasedInsights,
    required this.spendingTrends,
  });

  bool get hasExpenses => currentMonthExpenseCount > 0;
  bool get hasPreviousMonthExpenses => previousMonthExpenseCount > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIContext &&
          runtimeType == other.runtimeType &&
          periodStart == other.periodStart &&
          periodEnd == other.periodEnd &&
          currentMonthTotalPaise == other.currentMonthTotalPaise &&
          previousMonthTotalPaise == other.previousMonthTotalPaise &&
          currentMonthExpenseCount == other.currentMonthExpenseCount &&
          previousMonthExpenseCount == other.previousMonthExpenseCount &&
          topCategory == other.topCategory &&
          largestExpense == other.largestExpense &&
          ruleBasedInsights == other.ruleBasedInsights &&
          spendingTrends == other.spendingTrends &&
          _listEquals(categoryTotals, other.categoryTotals) &&
          _listEquals(recentExpenses, other.recentExpenses);

  @override
  int get hashCode => Object.hash(
        periodStart,
        periodEnd,
        currentMonthTotalPaise,
        previousMonthTotalPaise,
        currentMonthExpenseCount,
        previousMonthExpenseCount,
        topCategory,
        largestExpense,
        ruleBasedInsights,
        spendingTrends,
        Object.hashAll(categoryTotals),
        Object.hashAll(recentExpenses),
      );

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

import '../../../expense/domain/models/spending_analytics.dart';
import '../../../expense/domain/models/spending_insights.dart';
import '../../../expense/domain/models/spending_trends.dart';
import '../models/ai_context.dart';
import '../models/bounded_expense_summary.dart';

/// Pure domain service that transforms deterministic financial analysis into a bounded [AIContext].
///
/// Ensures strict data minimization before data is provided to any AI interpretation layer.
class AIContextBuilder {
  const AIContextBuilder();

  /// Pure transformation from trusted financial calculations to a bounded [AIContext].
  AIContext buildContext({
    required SpendingAnalytics analytics,
    required SpendingTrends trends,
    required SpendingInsights insights,
  }) {
    return AIContext(
      periodStart: analytics.currentPeriodStart,
      periodEnd: analytics.currentPeriodEnd,
      currentMonthTotalPaise: analytics.currentMonthTotalPaise,
      previousMonthTotalPaise: analytics.previousMonthTotalPaise,
      currentMonthExpenseCount: analytics.currentMonthExpenseCount,
      previousMonthExpenseCount: analytics.previousMonthExpenseCount,
      categoryTotals: analytics.categoryTotals,
      topCategory: analytics.topCategory,
      largestExpense: analytics.largestExpense != null
          ? BoundedExpenseSummary.fromExpense(analytics.largestExpense!)
          : null,
      recentExpenses: analytics.recentExpenses
          .map((e) => BoundedExpenseSummary.fromExpense(e))
          .toList(),
      ruleBasedInsights: insights,
      spendingTrends: trends,
    );
  }
}

import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../expense.dart';
import '../expense_category.dart';
import 'insight_priority.dart';
import 'insight_type.dart';
import 'spending_analytics.dart';
import 'spending_insight.dart';
import 'spending_insights.dart';
import 'spending_trends.dart';

export 'insight_priority.dart';
export 'insight_type.dart';
export 'spending_insight.dart';
export 'spending_insights.dart';

class SpendingInsightsCalculator {
  /// Pure deterministic calculation engine for spending insights.
  /// Derives structured [SpendingInsights] from [SpendingAnalytics], [SpendingTrends],
  /// and optional [expenses] collection.
  static SpendingInsights calculate({
    required SpendingAnalytics analytics,
    required SpendingTrends trends,
    List<Expense>? expenses,
  }) {
    if (!analytics.hasCurrentMonthExpenses && trends.dailySpending.isEmpty) {
      return const SpendingInsights(insights: []);
    }

    final generated = <SpendingInsight>[];

    // Helper: extract current and previous month expenses if provided
    final currentMonthExpenses = <Expense>[];
    final previousMonthExpenses = <Expense>[];
    if (expenses != null && expenses.isNotEmpty) {
      for (final exp in expenses) {
        final d = exp.expenseDate;
        if (!d.isBefore(analytics.currentPeriodStart) &&
            d.isBefore(analytics.currentPeriodEnd)) {
          currentMonthExpenses.add(exp);
        } else if (!d.isBefore(analytics.previousPeriodStart) &&
            d.isBefore(analytics.previousPeriodEnd)) {
          previousMonthExpenses.add(exp);
        }
      }
    }

    // -------------------------------------------------------------
    // Rule 1: Spending Increase (>= 20% increase: current * 5 >= previous * 6)
    // -------------------------------------------------------------
    if (analytics.previousMonthTotalPaise > 0 &&
        analytics.currentMonthTotalPaise > analytics.previousMonthTotalPaise &&
        (analytics.currentMonthTotalPaise * 5) >= (analytics.previousMonthTotalPaise * 6)) {
      final pct = analytics.monthOverMonthChangePercent ??
          (((analytics.currentMonthTotalPaise - analytics.previousMonthTotalPaise) /
                  analytics.previousMonthTotalPaise) *
              100.0);
      generated.add(SpendingInsight(
        type: InsightType.spendingIncrease,
        priority: InsightPriority.medium,
        title: 'Spending Increase',
        description: 'You spent ${pct.toStringAsFixed(0)}% more than last month.',
        amountPaise: analytics.monthOverMonthChangePaise,
        percentage: pct,
      ));
    }

    // -------------------------------------------------------------
    // Rule 2: Spending Decrease (>= 20% decrease: current * 5 <= previous * 4)
    // -------------------------------------------------------------
    if (analytics.previousMonthTotalPaise > 0 &&
        analytics.currentMonthTotalPaise < analytics.previousMonthTotalPaise &&
        (analytics.currentMonthTotalPaise * 5) <= (analytics.previousMonthTotalPaise * 4)) {
      final pct = analytics.monthOverMonthChangePercent?.abs() ??
          (((analytics.previousMonthTotalPaise - analytics.currentMonthTotalPaise) /
                  analytics.previousMonthTotalPaise) *
              100.0);
      generated.add(SpendingInsight(
        type: InsightType.spendingDecrease,
        priority: InsightPriority.medium,
        title: 'Spending Decrease',
        description: 'You spent ${pct.toStringAsFixed(0)}% less than last month.',
        amountPaise: analytics.monthOverMonthChangePaise.abs(),
        percentage: pct,
      ));
    }

    // -------------------------------------------------------------
    // Rule 6: Spending Concentration (Top category > 50% of spending)
    // -------------------------------------------------------------
    if (analytics.currentMonthTotalPaise > 0 &&
        analytics.categoryTotals.isNotEmpty &&
        (analytics.categoryTotals.first.totalAmountPaise * 2) >
            analytics.currentMonthTotalPaise) {
      final topCat = analytics.categoryTotals.first;
      final pct =
          (topCat.totalAmountPaise / analytics.currentMonthTotalPaise) * 100.0;
      generated.add(SpendingInsight(
        type: InsightType.spendingConcentration,
        priority: InsightPriority.high,
        title: 'High Spending Concentration',
        description:
            'More than half your spending was in ${topCat.category.displayName}.',
        category: topCat.category,
        amountPaise: topCat.totalAmountPaise,
        percentage: pct,
      ));
    }

    // -------------------------------------------------------------
    // Rule 3: Top Category
    // -------------------------------------------------------------
    if (analytics.topCategory != null && analytics.currentMonthTotalPaise > 0) {
      final topAmount = analytics.categoryTotals.isNotEmpty
          ? analytics.categoryTotals.first.totalAmountPaise
          : null;
      generated.add(SpendingInsight(
        type: InsightType.topCategory,
        priority: InsightPriority.low,
        title: 'Top Category',
        description:
            '${analytics.topCategory!.displayName} accounted for most spending this month.',
        category: analytics.topCategory,
        amountPaise: topAmount,
      ));
    }

    // -------------------------------------------------------------
    // Rule 4: Largest Expense
    // -------------------------------------------------------------
    if (analytics.largestExpense != null) {
      final largest = analytics.largestExpense!;
      generated.add(SpendingInsight(
        type: InsightType.largestExpense,
        priority: InsightPriority.low,
        title: 'Largest Expense',
        description:
            'Largest expense: ${CurrencyFormatter.formatPaise(largest.amountPaise)} on ${largest.category.displayName}.',
        amountPaise: largest.amountPaise,
        category: largest.category,
        date: largest.expenseDate,
      ));
    }

    // -------------------------------------------------------------
    // Rule 5: Highest Spending Day
    // -------------------------------------------------------------
    if (trends.highestSpendingDay != null) {
      final highDay = trends.highestSpendingDay!;
      generated.add(SpendingInsight(
        type: InsightType.unusuallyHighDay,
        priority: InsightPriority.low,
        title: 'Highest Spending Day',
        description:
            'Highest daily spending occurred on ${highDay.date.toShortDate()}.',
        amountPaise: highDay.totalAmountPaise,
        date: highDay.date,
      ));
    }

    // -------------------------------------------------------------
    // Rule 7: Category Growth & Drop (>= 30% difference)
    // -------------------------------------------------------------
    if (previousMonthExpenses.isNotEmpty && currentMonthExpenses.isNotEmpty) {
      final currentCatMap = <ExpenseCategory, int>{};
      for (final exp in currentMonthExpenses) {
        currentCatMap[exp.category] =
            (currentCatMap[exp.category] ?? 0) + exp.amountPaise;
      }
      final prevCatMap = <ExpenseCategory, int>{};
      for (final exp in previousMonthExpenses) {
        prevCatMap[exp.category] =
            (prevCatMap[exp.category] ?? 0) + exp.amountPaise;
      }

      for (final entry in currentCatMap.entries) {
        final cat = entry.key;
        final currVal = entry.value;
        final prevVal = prevCatMap[cat] ?? 0;

        if (prevVal > 0) {
          if ((currVal * 10) >= (prevVal * 13)) {
            final diff = currVal - prevVal;
            final pct = (diff / prevVal) * 100.0;
            generated.add(SpendingInsight(
              type: InsightType.categoryGrowth,
              priority: InsightPriority.medium,
              title: '${cat.displayName} Spending Growth',
              description:
                  '${cat.displayName} spending increased ${pct.toStringAsFixed(0)}% compared to last month.',
              category: cat,
              amountPaise: diff,
              percentage: pct,
            ));
          } else if ((currVal * 10) <= (prevVal * 7)) {
            final diff = prevVal - currVal;
            final pct = (diff / prevVal) * 100.0;
            generated.add(SpendingInsight(
              type: InsightType.categoryDrop,
              priority: InsightPriority.medium,
              title: '${cat.displayName} Spending Drop',
              description:
                  '${cat.displayName} spending dropped ${pct.abs().toStringAsFixed(0)}% compared to last month.',
              category: cat,
              amountPaise: diff,
              percentage: pct,
            ));
          }
        }
      }
    }

    // -------------------------------------------------------------
    // Rule 8: Frequent Category (> 40% of all expenses count)
    // -------------------------------------------------------------
    if (analytics.currentMonthExpenseCount > 0 &&
        currentMonthExpenses.isNotEmpty) {
      final catCountMap = <ExpenseCategory, int>{};
      for (final exp in currentMonthExpenses) {
        catCountMap[exp.category] = (catCountMap[exp.category] ?? 0) + 1;
      }

      for (final entry in catCountMap.entries) {
        final cat = entry.key;
        final count = entry.value;
        if (count * 10 > analytics.currentMonthExpenseCount * 4) {
          final pct = (count / analytics.currentMonthExpenseCount) * 100.0;
          generated.add(SpendingInsight(
            type: InsightType.frequentCategory,
            priority: InsightPriority.low,
            title: 'Frequent Category: ${cat.displayName}',
            description:
                'Most transactions (${pct.toStringAsFixed(0)}%) were ${cat.displayName} expenses.',
            category: cat,
            percentage: pct,
          ));
        }
      }
    }

    // -------------------------------------------------------------
    // Rule 9: High Expense Count (current count > 1.5x previous count)
    // -------------------------------------------------------------
    if (analytics.previousMonthExpenseCount > 0 &&
        (analytics.currentMonthExpenseCount * 2) >
            (analytics.previousMonthExpenseCount * 3)) {
      final pct = ((analytics.currentMonthExpenseCount -
                  analytics.previousMonthExpenseCount) /
              analytics.previousMonthExpenseCount) *
          100.0;
      generated.add(SpendingInsight(
        type: InsightType.highExpenseCount,
        priority: InsightPriority.medium,
        title: 'Increased Transaction Activity',
        description:
            'You recorded more expenses than last month (${analytics.currentMonthExpenseCount} vs ${analytics.previousMonthExpenseCount}).',
        percentage: pct,
      ));
    }

    // -------------------------------------------------------------
    // Sorting: Priority (High -> Medium -> Low), then Type name, then Title
    // -------------------------------------------------------------
    final sorted = List<SpendingInsight>.from(generated)
      ..sort((a, b) {
        final pCmp = a.priority.rank.compareTo(b.priority.rank);
        if (pCmp != 0) return pCmp;
        final tCmp = a.type.name.compareTo(b.type.name);
        if (tCmp != 0) return tCmp;
        return a.title.compareTo(b.title);
      });

    // Cap at top 8
    return SpendingInsights(insights: sorted.take(8).toList());
  }
}

/// Convenience top-level function for [SpendingInsightsCalculator.calculate].
SpendingInsights deriveSpendingInsights({
  required SpendingAnalytics analytics,
  required SpendingTrends trends,
  List<Expense>? expenses,
}) =>
    SpendingInsightsCalculator.calculate(
      analytics: analytics,
      trends: trends,
      expenses: expenses,
    );

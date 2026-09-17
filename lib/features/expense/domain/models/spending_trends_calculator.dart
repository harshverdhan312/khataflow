import '../expense.dart';
import '../expense_category.dart';
import 'spending_trend_point.dart';
import 'spending_trends.dart';

export 'spending_trend_point.dart';
export 'spending_trends.dart';

class SpendingTrendsCalculator {
  /// Pure deterministic trends calculation engine.
  /// Derives [SpendingTrends] from a list of [Expense] records.
  static SpendingTrends calculate(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return const SpendingTrends(
        dailySpending: [],
        weeklySpending: [],
        monthlySpending: [],
        categoryTrends: [],
        highestSpendingDay: null,
      );
    }

    // 1. Daily Aggregation (Calendar day [day 00:00, next day 00:00))
    final dailyMap = <DateTime, int>{};
    // For category-over-time trends (Category -> Day -> Total)
    final categoryDailyMap = <ExpenseCategory, Map<DateTime, int>>{};

    // 2. Weekly Aggregation (Monday 00:00 to following Monday 00:00)
    final weeklyMap = <DateTime, int>{};

    // 3. Monthly Aggregation (First day of month 00:00 to first day of next month 00:00)
    final monthlyMap = <DateTime, int>{};

    for (final expense in expenses) {
      final date = expense.expenseDate;

      // Daily bucket
      final dayStart = DateTime(date.year, date.month, date.day);
      dailyMap[dayStart] = (dailyMap[dayStart] ?? 0) + expense.amountPaise;

      // Category daily bucket
      final catMap = categoryDailyMap.putIfAbsent(expense.category, () => <DateTime, int>{});
      catMap[dayStart] = (catMap[dayStart] ?? 0) + expense.amountPaise;

      // Weekly bucket: Monday start
      final weekday = date.weekday; // 1 = Monday, 7 = Sunday
      final weekStart = DateTime(date.year, date.month, date.day - (weekday - 1));
      weeklyMap[weekStart] = (weeklyMap[weekStart] ?? 0) + expense.amountPaise;

      // Monthly bucket
      final monthStart = DateTime(date.year, date.month, 1);
      monthlyMap[monthStart] = (monthlyMap[monthStart] ?? 0) + expense.amountPaise;
    }

    // Build sorted daily trend points (oldest -> newest)
    final dailySpending = dailyMap.entries
        .map((e) => SpendingTrendPoint(
              periodStart: e.key,
              periodEnd: DateTime(e.key.year, e.key.month, e.key.day + 1),
              totalAmountPaise: e.value,
            ))
        .toList()
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));

    // Highest spending day: max total amount, tie-break: most recent date
    HighestSpendingDay? highestSpendingDay;
    if (dailySpending.isNotEmpty) {
      final sortedDays = List<SpendingTrendPoint>.from(dailySpending)
        ..sort((a, b) {
          final amountCmp = b.totalAmountPaise.compareTo(a.totalAmountPaise);
          if (amountCmp != 0) return amountCmp;
          return b.periodStart.compareTo(a.periodStart); // More recent day wins tie
        });
      highestSpendingDay = HighestSpendingDay(
        date: sortedDays.first.periodStart,
        totalAmountPaise: sortedDays.first.totalAmountPaise,
      );
    }

    // Build sorted weekly trend points (oldest -> newest)
    final weeklySpending = weeklyMap.entries
        .map((e) => SpendingTrendPoint(
              periodStart: e.key,
              periodEnd: DateTime(e.key.year, e.key.month, e.key.day + 7),
              totalAmountPaise: e.value,
            ))
        .toList()
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));

    // Build sorted monthly trend points (oldest -> newest)
    final monthlySpending = monthlyMap.entries
        .map((e) => SpendingTrendPoint(
              periodStart: e.key,
              periodEnd: DateTime(e.key.year, e.key.month + 1, 1),
              totalAmountPaise: e.value,
            ))
        .toList()
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));

    // Build sorted category trends (Category displayName asc -> PeriodStart asc)
    final categoryTrends = categoryDailyMap.entries.map((entry) {
      final points = entry.value.entries
          .map((e) => SpendingTrendPoint(
                periodStart: e.key,
                periodEnd: DateTime(e.key.year, e.key.month, e.key.day + 1),
                totalAmountPaise: e.value,
              ))
          .toList()
        ..sort((a, b) => a.periodStart.compareTo(b.periodStart));

      return CategoryTrend(
        category: entry.key,
        points: points,
      );
    }).toList()
      ..sort((a, b) => a.category.displayName.compareTo(b.category.displayName));

    return SpendingTrends(
      dailySpending: dailySpending,
      weeklySpending: weeklySpending,
      monthlySpending: monthlySpending,
      categoryTrends: categoryTrends,
      highestSpendingDay: highestSpendingDay,
    );
  }
}

/// Convenience top-level function for [SpendingTrendsCalculator.calculate].
SpendingTrends deriveSpendingTrends(List<Expense> expenses) =>
    SpendingTrendsCalculator.calculate(expenses);

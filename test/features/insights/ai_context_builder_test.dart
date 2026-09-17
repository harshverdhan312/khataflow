import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/category_spending.dart';
import 'package:khata_flow/features/expense/domain/models/insight_priority.dart';
import 'package:khata_flow/features/expense/domain/models/insight_type.dart';
import 'package:khata_flow/features/expense/domain/models/spending_analytics.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insight.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insights.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trend_point.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends.dart';
import 'package:khata_flow/features/insights/domain/services/ai_context_builder.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  group('AIContextBuilder Tests', () {
    const builder = AIContextBuilder();

    final now = DateTime(2026, 9, 15);
    final periodStart = DateTime(2026, 9, 1);
    final periodEnd = DateTime(2026, 10, 1);
    final prevStart = DateTime(2026, 8, 1);
    final prevEnd = DateTime(2026, 9, 1);

    final largestExp = Expense(
      id: 'e1',
      amountPaise: 450000,
      category: ExpenseCategory.food,
      note: 'Grocery bulk',
      expenseDate: DateTime(2026, 9, 5),
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
    );

    final analytics = SpendingAnalytics(
      currentPeriodStart: periodStart,
      currentPeriodEnd: periodEnd,
      previousPeriodStart: prevStart,
      previousPeriodEnd: prevEnd,
      currentMonthTotalPaise: 800000,
      previousMonthTotalPaise: 600000,
      monthOverMonthChangePaise: 200000,
      monthOverMonthChangePercent: 33.33,
      currentMonthExpenseCount: 12,
      previousMonthExpenseCount: 9,
      categoryTotals: const [
        CategorySpending(category: ExpenseCategory.food, totalAmountPaise: 500000),
        CategorySpending(category: ExpenseCategory.transport, totalAmountPaise: 300000),
      ],
      topCategory: ExpenseCategory.food,
      largestExpense: largestExp,
      averageExpensePaise: 66666,
      recentExpenses: [largestExp],
    );

    final trends = SpendingTrends(
      dailySpending: [
        SpendingTrendPoint(
          periodStart: DateTime(2026, 9, 5),
          periodEnd: DateTime(2026, 9, 6),
          totalAmountPaise: 450000,
        ),
      ],
      weeklySpending: const [],
      monthlySpending: [
        SpendingTrendPoint(
          periodStart: DateTime(2026, 8, 1),
          periodEnd: DateTime(2026, 9, 1),
          totalAmountPaise: 600000,
        ),
        SpendingTrendPoint(
          periodStart: DateTime(2026, 9, 1),
          periodEnd: DateTime(2026, 10, 1),
          totalAmountPaise: 800000,
        ),
      ],
      categoryTrends: const [],
      highestSpendingDay: HighestSpendingDay(
        date: DateTime(2026, 9, 5),
        totalAmountPaise: 450000,
      ),
    );

    const insights = SpendingInsights(
      insights: [
        SpendingInsight(
          type: InsightType.spendingIncrease,
          priority: InsightPriority.high,
          title: 'Spending Increased',
          description: 'You spent 33% more than last month',
          percentage: 33.33,
        ),
      ],
    );

    test('buildContext accurately transfers all trusted metrics to AIContext', () {
      final context = builder.buildContext(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      expect(context.periodStart, periodStart);
      expect(context.periodEnd, periodEnd);
      expect(context.currentMonthTotalPaise, 800000);
      expect(context.previousMonthTotalPaise, 600000);
      expect(context.currentMonthExpenseCount, 12);
      expect(context.previousMonthExpenseCount, 9);
      expect(context.categoryTotals.length, 2);
      expect(context.topCategory, ExpenseCategory.food);
      expect(context.largestExpense, largestExp);
      expect(context.recentExpenses.length, 1);
      expect(context.ruleBasedInsights, insights);
      expect(context.spendingTrends, trends);
      expect(context.hasExpenses, isTrue);
      expect(context.hasPreviousMonthExpenses, isTrue);
    });

    test('buildContext preserves exact integer paise and timestamps without rounding', () {
      final context = builder.buildContext(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      expect(context.currentMonthTotalPaise, isA<int>());
      expect(context.currentMonthTotalPaise, 800000);
      expect(context.previousMonthTotalPaise, isA<int>());
      expect(context.previousMonthTotalPaise, 600000);
    });

    test('buildContext is pure, idempotent, and produces identical outputs across calls', () {
      final context1 = builder.buildContext(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      final context2 = builder.buildContext(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      expect(context1, equals(context2));
      expect(context1.hashCode, equals(context2.hashCode));
    });
  });
}

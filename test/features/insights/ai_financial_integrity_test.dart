import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/spending_analytics_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insights_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends_calculator.dart';
import 'package:khata_flow/features/insights/data/providers/mock_ai_insight_provider.dart';
import 'package:khata_flow/features/insights/data/repositories/ai_insight_repository_impl.dart';
import 'package:khata_flow/features/insights/presentation/controllers/ai_insight_cache.dart';
import 'package:khata_flow/features/insights/presentation/controllers/ai_insight_controller.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  group('AI Financial Integrity & Non-Mutation Invariant Tests', () {
    final now = DateTime(2026, 9, 15);

    late List<Expense> originalExpenses;

    setUp(() {
      originalExpenses = [
        Expense(
          id: 'exp_1',
          amountPaise: 425000,
          category: ExpenseCategory.food,
          note: 'Dinner with friends',
          expenseDate: DateTime(2026, 9, 3),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
        Expense(
          id: 'exp_2',
          amountPaise: 180000,
          category: ExpenseCategory.transport,
          note: 'Fuel refill',
          expenseDate: DateTime(2026, 9, 7),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
        Expense(
          id: 'exp_3',
          amountPaise: 95000,
          category: ExpenseCategory.shopping,
          note: 'Household supplies',
          expenseDate: DateTime(2026, 9, 12),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
      ];
    });

    test('generating AI insights leaves all M7 analytics, trends, and rule-based insights unchanged',
        () async {
      // 1. Snapshot pre-AI state
      final preAnalytics = deriveSpendingAnalytics(originalExpenses, now: now);
      final preTrends = deriveSpendingTrends(originalExpenses);
      final preInsights = deriveSpendingInsights(
        analytics: preAnalytics,
        trends: preTrends,
        expenses: originalExpenses,
      );

      final repository = const AIInsightRepositoryImpl(
        provider: MockAIInsightProvider(),
      );
      final cache = AIInsightCache();
      final controller = AIInsightController(
        repository: repository,
        cache: cache,
      );

      // 2. Execute monthly summary request
      await controller.requestMonthlySummary(
        analytics: preAnalytics,
        trends: preTrends,
        insights: preInsights,
      );
      expect(controller.state.isSuccess, isTrue);

      // 3. Execute spending advice request
      await controller.requestSpendingAdvice(
        analytics: preAnalytics,
        trends: preTrends,
        insights: preInsights,
      );
      expect(controller.state.isSuccess, isTrue);

      // 4. Recalculate post-AI state
      final postAnalytics = deriveSpendingAnalytics(originalExpenses, now: now);
      final postTrends = deriveSpendingTrends(originalExpenses);
      final postInsights = deriveSpendingInsights(
        analytics: postAnalytics,
        trends: postTrends,
        expenses: originalExpenses,
      );

      // 5. Invariant assertion: M7 values are bit-for-bit identical
      expect(postAnalytics.currentMonthTotalPaise,
          equals(preAnalytics.currentMonthTotalPaise));
      expect(postAnalytics.currentMonthExpenseCount,
          equals(preAnalytics.currentMonthExpenseCount));
      expect(postAnalytics.topCategory, equals(preAnalytics.topCategory));
      expect(postAnalytics.largestExpense?.amountPaise,
          equals(preAnalytics.largestExpense?.amountPaise));

      expect(postTrends.dailySpending.length,
          equals(preTrends.dailySpending.length));
      expect(postTrends.highestSpendingDay?.totalAmountPaise,
          equals(preTrends.highestSpendingDay?.totalAmountPaise));

      expect(postInsights.insights.length, equals(preInsights.insights.length));
      for (int i = 0; i < preInsights.insights.length; i++) {
        expect(postInsights.insights[i].type, equals(preInsights.insights[i].type));
        expect(postInsights.insights[i].priority,
            equals(preInsights.insights[i].priority));
        expect(postInsights.insights[i].amountPaise,
            equals(preInsights.insights[i].amountPaise));
      }

      // 6. Verify Expense list was not mutated
      expect(originalExpenses.length, equals(3));
      expect(originalExpenses[0].amountPaise, equals(425000));
      expect(originalExpenses[1].amountPaise, equals(180000));
      expect(originalExpenses[2].amountPaise, equals(95000));
    });
  });
}

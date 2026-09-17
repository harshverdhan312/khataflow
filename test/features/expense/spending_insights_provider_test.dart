import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/expense/presentation/providers/spending_insights_provider.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  Expense createTestExpense({
    required String id,
    required int amountPaise,
    required ExpenseCategory category,
    required DateTime expenseDate,
  }) {
    return Expense(
      id: id,
      amountPaise: amountPaise,
      category: category,
      expenseDate: expenseDate,
      createdAt: expenseDate,
      updatedAt: expenseDate,
      syncStatus: SyncStatus.synced,
    );
  }

  group('SpendingInsightsProvider Tests', () {
    test('Empty expenses stream yields empty SpendingInsights', () async {
      final container = ProviderContainer(
        overrides: [
          expensesStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);

      // Wait for stream to emit
      await container.read(expensesStreamProvider.future);
      final asyncInsights = container.read(spendingInsightsProvider);
      expect(asyncInsights.asData?.value.isEmpty, isTrue);
    });

    test('Expenses stream derivation preserves analytics, trends, and M7.3 insights ordering', () async {
      final now = DateTime.now();
      final currentMonthDate = DateTime(now.year, now.month, 5);

      final expenses = [
        createTestExpense(
          id: 'exp-1',
          amountPaise: 800000, // ₹8,000 on Food (> 50% concentration -> High priority)
          category: ExpenseCategory.food,
          expenseDate: currentMonthDate,
        ),
        createTestExpense(
          id: 'exp-2',
          amountPaise: 200000, // ₹2,000 on Transport
          category: ExpenseCategory.transport,
          expenseDate: currentMonthDate,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          expensesStreamProvider.overrideWith((ref) => Stream.value(expenses)),
        ],
      );
      addTearDown(container.dispose);

      // Wait for stream to emit
      await container.read(expensesStreamProvider.future);

      final asyncAnalytics = container.read(spendingAnalyticsProvider);
      expect(asyncAnalytics.asData?.value.currentMonthTotalPaise, 1000000);

      final asyncTrends = container.read(spendingTrendsProvider);
      expect(asyncTrends.asData?.value.dailySpending.length, 1);

      final asyncInsights = container.read(spendingInsightsProvider);
      final insights = asyncInsights.asData?.value;
      expect(insights, isNotNull);
      expect(insights!.hasInsights, isTrue);
      // High priority concentration insight is first
      expect(insights.highestPriority?.type, InsightType.spendingConcentration);
    });
  });
}

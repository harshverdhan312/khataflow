import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/category_spending.dart';
import 'package:khata_flow/features/expense/domain/models/insight_priority.dart';
import 'package:khata_flow/features/expense/domain/models/insight_type.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insight.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insights.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends.dart';
import 'package:khata_flow/features/insights/data/providers/mock_ai_insight_provider.dart';
import 'package:khata_flow/features/insights/domain/models/ai_context.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_request.dart';
import 'package:khata_flow/features/insights/domain/models/ai_request_type.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  group('MockAIInsightProvider Tests', () {
    const provider = MockAIInsightProvider();
    final now = DateTime(2026, 9, 15);

    AIContext createTestContext({
      int count = 5,
      int totalPaise = 250000,
      ExpenseCategory? topCategory = ExpenseCategory.food,
      SpendingInsights insights = const SpendingInsights(insights: []),
    }) {
      return AIContext(
        periodStart: DateTime(2026, 9, 1),
        periodEnd: DateTime(2026, 10, 1),
        currentMonthTotalPaise: totalPaise,
        previousMonthTotalPaise: 150000,
        currentMonthExpenseCount: count,
        previousMonthExpenseCount: 3,
        categoryTotals: [
          if (topCategory != null)
            CategorySpending(category: topCategory, totalAmountPaise: totalPaise),
        ],
        topCategory: topCategory,
        largestExpense: count > 0
            ? Expense(
                id: 'exp1',
                amountPaise: totalPaise,
                category: topCategory ?? ExpenseCategory.other,
                expenseDate: now,
                createdAt: now,
                updatedAt: now,
                syncStatus: SyncStatus.synced,
              )
            : null,
        recentExpenses: const [],
        ruleBasedInsights: insights,
        spendingTrends: const SpendingTrends(
          dailySpending: [],
          weeklySpending: [],
          monthlySpending: [],
          categoryTrends: [],
        ),
      );
    }

    test('generateInsight for monthlySummary with expenses returns contextual output', () async {
      final context = createTestContext(
        count: 8,
        totalPaise: 500000,
        topCategory: ExpenseCategory.food,
      );

      final request = AIInsightRequest(
        context: context,
        requestType: AIRequestType.monthlySummary,
      );

      final response = await provider.generateInsight(request);

      expect(response.insight.title, contains('Food'));
      expect(response.insight.explanation, contains('8 expenses'));
      expect(response.insight.explanation, contains('Food'));
      expect(response.insight.recommendation, isNotEmpty);
      expect(response.providerMetadata?['provider'], 'MockAIInsightProvider');
    });

    test('generateInsight for monthlySummary without expenses returns empty state advice', () async {
      final context = createTestContext(
        count: 0,
        totalPaise: 0,
        topCategory: null,
      );

      final request = AIInsightRequest(
        context: context,
        requestType: AIRequestType.monthlySummary,
      );

      final response = await provider.generateInsight(request);

      expect(response.insight.title, contains('No spending'));
      expect(response.insight.explanation, isNotEmpty);
      expect(response.insight.recommendation, contains('Record your expenses'));
    });

    test('generateInsight for spendingAdvice derives focus from rule-based insights', () async {
      const highInsight = SpendingInsight(
        type: InsightType.spendingConcentration,
        priority: InsightPriority.high,
        title: 'Spending is concentrated',
        description: 'Food accounted for over 75% of your spending this month.',
      );

      final context = createTestContext(
        count: 10,
        totalPaise: 900000,
        topCategory: ExpenseCategory.food,
        insights: const SpendingInsights(insights: [highInsight]),
      );

      final request = AIInsightRequest(
        context: context,
        requestType: AIRequestType.spendingAdvice,
      );

      final response = await provider.generateInsight(request);

      expect(response.insight.title, contains('Spending is concentrated'));
      expect(response.insight.explanation, contains('Food accounted for over 75%'));
      expect(response.insight.recommendation, contains('Food'));
      expect(response.insight.supportingInsightType, InsightType.spendingConcentration);
    });

    test('different contexts produce distinct deterministic outputs without hallucinations', () async {
      final foodContext = createTestContext(
        count: 4,
        topCategory: ExpenseCategory.food,
      );
      final transportContext = createTestContext(
        count: 7,
        topCategory: ExpenseCategory.transport,
      );

      final responseFood = await provider.generateInsight(
        AIInsightRequest(context: foodContext, requestType: AIRequestType.monthlySummary),
      );
      final responseTransport = await provider.generateInsight(
        AIInsightRequest(context: transportContext, requestType: AIRequestType.monthlySummary),
      );

      expect(responseFood.insight.title, isNot(equals(responseTransport.insight.title)));
      expect(responseFood.insight.title, contains('Food'));
      expect(responseTransport.insight.title, contains('Transport'));
    });
  });
}

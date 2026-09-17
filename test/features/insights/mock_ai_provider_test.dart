import 'package:flutter_test/flutter_test.dart';
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
import 'package:khata_flow/features/insights/domain/models/bounded_expense_summary.dart';

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
            ? BoundedExpenseSummary(
                amountPaise: totalPaise,
                category: topCategory ?? ExpenseCategory.other,
                date: now,
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
        totalPaise: 650000,
        topCategory: ExpenseCategory.food,
        insights: const SpendingInsights(
          insights: [
            SpendingInsight(
              type: InsightType.topCategory,
              priority: InsightPriority.high,
              title: 'Food dominant',
              description: 'Food took up 60% of spending',
            ),
          ],
        ),
      );

      final request = AIInsightRequest(
        context: context,
        requestType: AIRequestType.monthlySummary,
      );

      final response = await provider.generateInsight(request);

      expect(response.insight.title.contains('Food'), isTrue);
      expect(response.insight.explanation.contains('8 expenses'), isTrue);
      expect(response.insight.explanation.contains('Food'), isTrue);
      expect(response.insight.supportingInsightType, equals(InsightType.topCategory));
      expect(response.insight.recommendation, isNotEmpty);
      expect(response.providerMetadata?['deterministic'], equals('true'));
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

      expect(response.insight.title, equals('No spending recorded this month'));
      expect(response.insight.supportingInsightType, isNull);
      expect(response.insight.recommendation, isNotEmpty);
    });

    test('generateInsight for spendingAdvice derives focus from rule-based insights', () async {
      final context = createTestContext(
        count: 5,
        totalPaise: 300000,
        topCategory: ExpenseCategory.transport,
        insights: const SpendingInsights(
          insights: [
            SpendingInsight(
              type: InsightType.spendingConcentration,
              priority: InsightPriority.high,
              title: 'High transit concentration',
              description: 'Transport took up 70% of expenses this week',
            ),
          ],
        ),
      );

      final request = AIInsightRequest(
        context: context,
        requestType: AIRequestType.spendingAdvice,
      );

      final response = await provider.generateInsight(request);

      expect(response.insight.title.contains('High transit concentration'), isTrue);
      expect(response.insight.supportingInsightType, equals(InsightType.spendingConcentration));
      expect(response.insight.recommendation.contains('Transport'), isTrue);
    });

    test('different contexts produce distinct deterministic outputs without hallucinations', () async {
      final contextFood = createTestContext(topCategory: ExpenseCategory.food);
      final contextShopping = createTestContext(topCategory: ExpenseCategory.shopping);

      final resFood = await provider.generateInsight(
        AIInsightRequest(context: contextFood, requestType: AIRequestType.monthlySummary),
      );
      final resShopping = await provider.generateInsight(
        AIInsightRequest(context: contextShopping, requestType: AIRequestType.monthlySummary),
      );

      expect(resFood.insight.title, isNot(equals(resShopping.insight.title)));
      expect(resFood.insight.explanation, isNot(equals(resShopping.insight.explanation)));
    });
  });
}

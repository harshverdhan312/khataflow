import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/category_spending.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insights.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends.dart';
import 'package:khata_flow/features/insights/data/providers/mock_ai_insight_provider.dart';
import 'package:khata_flow/features/insights/data/repositories/ai_insight_repository_impl.dart';
import 'package:khata_flow/features/insights/domain/models/ai_context.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_request.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_response.dart';
import 'package:khata_flow/features/insights/domain/models/ai_request_type.dart';
import 'package:khata_flow/features/insights/domain/repositories/ai_insight_provider.dart';
import 'package:khata_flow/features/insights/domain/services/ai_response_validator.dart';

class FailingMockProvider implements AIInsightProvider {
  final AIInsight invalidInsight;

  FailingMockProvider(this.invalidInsight);

  @override
  Future<AIInsightResponse> generateInsight(AIInsightRequest request) async {
    return AIInsightResponse(insight: invalidInsight);
  }
}

void main() {
  group('AIInsightRepositoryImpl Tests', () {
    final validContext = AIContext(
      periodStart: DateTime(2026, 9, 1),
      periodEnd: DateTime(2026, 10, 1),
      currentMonthTotalPaise: 450000,
      previousMonthTotalPaise: 300000,
      currentMonthExpenseCount: 6,
      previousMonthExpenseCount: 4,
      categoryTotals: const [
        CategorySpending(category: ExpenseCategory.food, totalAmountPaise: 450000),
      ],
      topCategory: ExpenseCategory.food,
      largestExpense: null,
      recentExpenses: const [],
      ruleBasedInsights: const SpendingInsights(insights: []),
      spendingTrends: const SpendingTrends(
        dailySpending: [],
        weeklySpending: [],
        monthlySpending: [],
        categoryTrends: [],
      ),
    );

    test('repository generates and validates insight successfully via mock provider', () async {
      const repository = AIInsightRepositoryImpl(
        provider: MockAIInsightProvider(),
        validator: AIResponseValidator(),
      );

      final request = AIInsightRequest(
        context: validContext,
        requestType: AIRequestType.monthlySummary,
      );

      final response = await repository.generateInsight(request);

      expect(response.insight.title, isNotEmpty);
      expect(response.insight.explanation, isNotEmpty);
      expect(response.insight.recommendation, isNotEmpty);
      expect(response.providerMetadata?['provider'], 'MockAIInsightProvider');
    });

    test('repository intercepts and rejects invalid provider output via validator', () async {
      final invalidInsight = AIInsight(
        title: '', // Invalid empty title
        explanation: 'Valid explanation',
        recommendation: 'Valid recommendation',
        generatedAt: DateTime.now(),
      );

      final repository = AIInsightRepositoryImpl(
        provider: FailingMockProvider(invalidInsight),
        validator: const AIResponseValidator(),
      );

      final request = AIInsightRequest(
        context: validContext,
        requestType: AIRequestType.monthlySummary,
      );

      expect(
        () => repository.generateInsight(request),
        throwsA(isA<AIValidationException>()),
      );
    });
  });
}

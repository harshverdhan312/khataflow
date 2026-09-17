import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/spending_analytics_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insights_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends_calculator.dart';
import 'package:khata_flow/features/insights/data/config/ai_provider_config.dart';
import 'package:khata_flow/features/insights/data/network/ai_http_client.dart';
import 'package:khata_flow/features/insights/data/providers/real_ai_insight_provider.dart';
import 'package:khata_flow/features/insights/data/repositories/ai_insight_repository_impl.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_request.dart';
import 'package:khata_flow/features/insights/domain/models/ai_request_type.dart';
import 'package:khata_flow/features/insights/domain/services/ai_context_builder.dart';
import 'package:khata_flow/features/insights/domain/services/ai_response_validator.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

class TestGatewayHttpClient implements AiHttpClient {
  String? lastCapturedPayload;

  @override
  Future<AiHttpResponse> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    lastCapturedPayload = body;

    return const AiHttpResponse(
      statusCode: 200,
      body: '''
      {
        "title": "Dining is your main focus this month",
        "explanation": "Food made up ₹5,000 of your ₹8,000 total across 4 transactions.",
        "recommendation": "Track grocery purchases separately to spot areas for savings.",
        "supportingInsightType": "topCategory"
      }
      ''',
    );
  }
}

void main() {
  group('AI Insight Real Integration Tests', () {
    test('full end-to-end M7 -> M8 pipeline executes cleanly without mutating domain state', () async {
      final now = DateTime(2026, 9, 15);
      final expenses = [
        Expense(
          id: 'exp_food_1',
          amountPaise: 300000,
          category: ExpenseCategory.food,
          note: 'Dinner with team',
          expenseDate: DateTime(2026, 9, 2),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
        Expense(
          id: 'exp_food_2',
          amountPaise: 200000,
          category: ExpenseCategory.food,
          note: 'Groceries',
          expenseDate: DateTime(2026, 9, 5),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
        Expense(
          id: 'exp_transport_1',
          amountPaise: 300000,
          category: ExpenseCategory.transport,
          note: 'Monthly metro pass',
          expenseDate: DateTime(2026, 9, 8),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
      ];

      // 1. Compute M7 Deterministic Layer
      final analytics = deriveSpendingAnalytics(expenses, now: now);
      final trends = deriveSpendingTrends(expenses);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );

      expect(analytics.currentMonthTotalPaise, 800000);
      expect(analytics.topCategory, ExpenseCategory.food);

      // 2. Build AI Context (M8.1)
      const contextBuilder = AIContextBuilder();
      final aiContext = contextBuilder.buildContext(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      expect(aiContext.currentMonthTotalPaise, 800000);
      expect(aiContext.topCategory, ExpenseCategory.food);

      // 3. Setup Real AI Provider with Gateway transport (M8.2)
      final testClient = TestGatewayHttpClient();
      final config = AIProviderConfig.gateway(
        gatewayUrl: Uri.parse('https://secure.khataflow.app/ai/insights'),
        userAuthToken: 'jwt_secure_session',
      );

      final realProvider = RealAIInsightProvider(
        config: config,
        httpClient: testClient,
      );

      const validator = AIResponseValidator();
      final repository = AIInsightRepositoryImpl(
        provider: realProvider,
        validator: validator,
      );

      // 4. Request Insight
      final request = AIInsightRequest(
        context: aiContext,
        requestType: AIRequestType.monthlySummary,
      );

      final response = await repository.generateInsight(request);

      // 5. Verify Structured Response Output
      expect(response.insight.title, 'Dining is your main focus this month');
      expect(response.insight.explanation, contains('Food made up ₹5,000'));
      expect(response.insight.recommendation, contains('Track grocery purchases'));
      expect(response.insight.supportingInsightType, InsightType.topCategory);

      // 6. Verify Data Minimization in captured payload
      final payload = testClient.lastCapturedPayload!;
      expect(payload.contains('exp_food_1'), isFalse);
      expect(payload.contains('exp_food_2'), isFalse);
      expect(payload.contains('exp_transport_1'), isFalse);
      expect(payload.contains('syncStatus'), isFalse);
      expect(payload.contains('Food'), isTrue);
      expect(payload.contains('₹8,000'), isTrue);

      // 7. Verify Deterministic Integrity of original data
      expect(expenses.length, 3);
      expect(analytics.currentMonthTotalPaise, 800000);
    });
  });
}

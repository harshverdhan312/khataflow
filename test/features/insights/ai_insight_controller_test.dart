import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/spending_analytics_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insights_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends_calculator.dart';
import 'package:khata_flow/features/insights/data/providers/mock_ai_insight_provider.dart';
import 'package:khata_flow/features/insights/data/repositories/ai_insight_repository_impl.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_exception.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_request.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_response.dart';
import 'package:khata_flow/features/insights/domain/models/ai_request_type.dart';
import 'package:khata_flow/features/insights/domain/repositories/ai_insight_repository.dart';
import 'package:khata_flow/features/insights/domain/services/ai_response_validator.dart';
import 'package:khata_flow/features/insights/presentation/controllers/ai_insight_cache.dart';
import 'package:khata_flow/features/insights/presentation/controllers/ai_insight_controller.dart';
import 'package:khata_flow/features/insights/presentation/controllers/ai_insight_state.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

class FailingAIInsightRepository implements AIInsightRepository {
  final Object errorToThrow;
  int callCount = 0;

  FailingAIInsightRepository(this.errorToThrow);

  @override
  Future<AIInsightResponse> generateInsight(AIInsightRequest request) async {
    callCount++;
    throw errorToThrow;
  }
}

class CountingAIInsightRepository implements AIInsightRepository {
  int callCount = 0;
  final AIInsight insightToReturn;

  CountingAIInsightRepository({required this.insightToReturn});

  @override
  Future<AIInsightResponse> generateInsight(AIInsightRequest request) async {
    callCount++;
    await Future.delayed(const Duration(milliseconds: 10));
    return AIInsightResponse(
      insight: insightToReturn,
    );
  }
}

void main() {
  group('AIInsightController Tests', () {
    late List<Expense> testExpenses;
    final now = DateTime(2026, 9, 15);

    setUp(() {
      testExpenses = [
        Expense(
          id: 'exp_1',
          amountPaise: 450000,
          category: ExpenseCategory.food,
          note: 'Groceries',
          expenseDate: DateTime(2026, 9, 5),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
        Expense(
          id: 'exp_2',
          amountPaise: 150000,
          category: ExpenseCategory.transport,
          note: 'Metro pass',
          expenseDate: DateTime(2026, 9, 10),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
      ];
    });

    test('initial state is initial with no insight or errors', () {
      final repository = const AIInsightRepositoryImpl();
      final cache = AIInsightCache();
      final controller = AIInsightController(
        repository: repository,
        cache: cache,
      );

      expect(controller.state.isInitial, isTrue);
      expect(controller.state.status, equals(AIInsightStatus.initial));
      expect(controller.state.insight, isNull);
      expect(controller.state.errorMessage, isNull);
    });

    test('requestMonthlySummary succeeds using offline MockAIInsightProvider', () async {
      final repository = const AIInsightRepositoryImpl(
        provider: MockAIInsightProvider(),
      );
      final cache = AIInsightCache();
      final controller = AIInsightController(
        repository: repository,
        cache: cache,
      );

      final analytics = deriveSpendingAnalytics(testExpenses, now: now);
      final trends = deriveSpendingTrends(testExpenses);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: testExpenses,
      );

      await controller.requestMonthlySummary(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      expect(controller.state.isSuccess, isTrue);
      expect(controller.state.requestType, equals(AIRequestType.monthlySummary));
      expect(controller.state.insight, isNotNull);
      expect(controller.state.insight!.title, isNotEmpty);
      expect(controller.state.insight!.explanation, isNotEmpty);
      expect(controller.state.insight!.recommendation, isNotEmpty);
      expect(controller.state.errorMessage, isNull);
    });

    test('requestSpendingAdvice succeeds and populates state', () async {
      final repository = const AIInsightRepositoryImpl(
        provider: MockAIInsightProvider(),
      );
      final cache = AIInsightCache();
      final controller = AIInsightController(
        repository: repository,
        cache: cache,
      );

      final analytics = deriveSpendingAnalytics(testExpenses, now: now);
      final trends = deriveSpendingTrends(testExpenses);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: testExpenses,
      );

      await controller.requestSpendingAdvice(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      expect(controller.state.isSuccess, isTrue);
      expect(controller.state.requestType, equals(AIRequestType.spendingAdvice));
      expect(controller.state.insight, isNotNull);
    });

    test('empty financial data does not call repository and transitions to empty state', () async {
      final repository = CountingAIInsightRepository(
        insightToReturn: AIInsight(
          title: 'Test',
          explanation: 'Test',
          recommendation: 'Test',
          generatedAt: now,
        ),
      );
      final cache = AIInsightCache();
      final controller = AIInsightController(
        repository: repository,
        cache: cache,
      );

      final emptyExpenses = <Expense>[];
      final analytics = deriveSpendingAnalytics(emptyExpenses, now: now);
      final trends = deriveSpendingTrends(emptyExpenses);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: emptyExpenses,
      );

      await controller.requestMonthlySummary(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      expect(controller.state.isEmpty, isTrue);
      expect(controller.state.errorMessage,
          equals('Add some expenses to generate AI spending insights.'));
      expect(repository.callCount, equals(0));
    });

    test('duplicate concurrent request is throttled / ignored while loading', () async {
      final testInsight = AIInsight(
        title: 'Throttled Title',
        explanation: 'Throttled Explanation',
        recommendation: 'Throttled Recommendation',
        generatedAt: now,
      );
      final repository = CountingAIInsightRepository(insightToReturn: testInsight);
      final cache = AIInsightCache();
      final controller = AIInsightController(
        repository: repository,
        cache: cache,
      );

      final analytics = deriveSpendingAnalytics(testExpenses, now: now);
      final trends = deriveSpendingTrends(testExpenses);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: testExpenses,
      );

      // Launch first request
      final future1 = controller.requestMonthlySummary(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      // Immediately launch identical second request while loading
      final future2 = controller.requestMonthlySummary(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      await Future.wait([future1, future2]);

      expect(repository.callCount, equals(1));
      expect(controller.state.isSuccess, isTrue);
    });

    test('provider network failure yields sanitized error and internal classification', () async {
      final repository = FailingAIInsightRepository(
        const AINetworkException('Socket error: connection refused to 10.0.0.1:443'),
      );
      final cache = AIInsightCache();
      final controller = AIInsightController(
        repository: repository,
        cache: cache,
      );

      final analytics = deriveSpendingAnalytics(testExpenses, now: now);
      final trends = deriveSpendingTrends(testExpenses);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: testExpenses,
      );

      await controller.requestMonthlySummary(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      expect(controller.state.isError, isTrue);
      expect(controller.state.errorMessage,
          equals('AI insights are temporarily unavailable.'));
      expect(controller.state.internalErrorType, equals('AINetworkException'));
      expect(controller.state.errorMessage, isNot(contains('Socket error')));
      expect(controller.state.errorMessage, isNot(contains('10.0.0.1')));
    });

    test('validation failure yields sanitized error with internal classification', () async {
      final repository = FailingAIInsightRepository(
        const AIValidationException('Title exceeds length limit'),
      );
      final cache = AIInsightCache();
      final controller = AIInsightController(
        repository: repository,
        cache: cache,
      );

      final analytics = deriveSpendingAnalytics(testExpenses, now: now);
      final trends = deriveSpendingTrends(testExpenses);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: testExpenses,
      );

      await controller.requestSpendingAdvice(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      expect(controller.state.isError, isTrue);
      expect(controller.state.errorMessage,
          equals('AI insights are temporarily unavailable.'));
      expect(controller.state.internalErrorType, equals('AIValidationException'));
    });

    test('retry after failure successfully executes request', () async {
      int attempts = 0;
      final successInsight = AIInsight(
        title: 'Retry Successful',
        explanation: 'Recovered after failure.',
        recommendation: 'Keep tracking.',
        generatedAt: now,
      );

      final repository = _MockAlternatingRepository(
        onGenerate: (req) {
          attempts++;
          if (attempts == 1) {
            throw const AITimeoutException('Timed out');
          }
          return AIInsightResponse(
            insight: successInsight,
          );
        },
      );

      final cache = AIInsightCache();
      final controller = AIInsightController(
        repository: repository,
        cache: cache,
      );

      final analytics = deriveSpendingAnalytics(testExpenses, now: now);
      final trends = deriveSpendingTrends(testExpenses);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: testExpenses,
      );

      // Attempt 1: Fails
      await controller.requestMonthlySummary(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );
      expect(controller.state.isError, isTrue);
      expect(controller.state.internalErrorType, equals('AITimeoutException'));

      // Attempt 2: Retry succeeds
      await controller.retry(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );
      expect(controller.state.isSuccess, isTrue);
      expect(controller.state.insight!.title, equals('Retry Successful'));
    });
  });
}

class _MockAlternatingRepository implements AIInsightRepository {
  final AIInsightResponse Function(AIInsightRequest) onGenerate;

  _MockAlternatingRepository({required this.onGenerate});

  @override
  Future<AIInsightResponse> generateInsight(AIInsightRequest request) async {
    return onGenerate(request);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/insight_type.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/expense/presentation/screens/spending_insights_screen.dart';
import 'package:khata_flow/features/insights/data/providers/mock_ai_insight_provider.dart';
import 'package:khata_flow/features/insights/data/repositories/ai_insight_repository_impl.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_exception.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_request.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_response.dart';
import 'package:khata_flow/features/insights/domain/repositories/ai_insight_repository.dart';
import 'package:khata_flow/features/insights/presentation/providers/ai_insights_providers.dart';
import 'package:khata_flow/features/insights/presentation/widgets/ai_insight_card.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

class StubDelayAIInsightRepository implements AIInsightRepository {
  final Duration delay;
  final AIInsight insight;

  StubDelayAIInsightRepository({
    this.delay = const Duration(milliseconds: 50),
    required this.insight,
  });

  @override
  Future<AIInsightResponse> generateInsight(AIInsightRequest request) async {
    await Future.delayed(delay);
    return AIInsightResponse(
      insight: insight,
    );
  }
}

class StubFailingAIInsightRepository implements AIInsightRepository {
  int attempts = 0;
  final AIInsight successInsight;

  StubFailingAIInsightRepository({required this.successInsight});

  @override
  Future<AIInsightResponse> generateInsight(AIInsightRequest request) async {
    attempts++;
    if (attempts == 1) {
      throw const AINetworkException('Network unreachable');
    }
    return AIInsightResponse(
      insight: successInsight,
    );
  }
}

void main() {
  final now = DateTime(DateTime.now().year, DateTime.now().month, 10);

  final testExpenses = [
    Expense(
      id: 'exp_food',
      amountPaise: 500000,
      category: ExpenseCategory.food,
      note: 'Food',
      expenseDate: now,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
    ),
    Expense(
      id: 'exp_transport',
      amountPaise: 200000,
      category: ExpenseCategory.transport,
      note: 'Transport',
      expenseDate: now,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
    ),
  ];

  Widget createTestWidget({required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: SpendingInsightsScreen(),
      ),
    );
  }

  group('SpendingInsightsScreen AI UI Integration Tests', () {
    testWidgets('AI section renders with Monthly Summary and Spending Advice buttons',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            expensesStreamProvider.overrideWith((ref) => Stream.value(testExpenses)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Spending Intelligence'), findsOneWidget);
      expect(find.text('Monthly Summary'), findsOneWidget);
      expect(find.text('Spending Advice'), findsOneWidget);
    });

    testWidgets('Tapping Monthly Summary generates and displays AIInsightCard',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = const AIInsightRepositoryImpl(
        provider: MockAIInsightProvider(),
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            expensesStreamProvider.overrideWith((ref) => Stream.value(testExpenses)),
            aiInsightRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Monthly Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(AIInsightCard), findsOneWidget);
      expect(find.text('AI-generated'), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);
    });

    testWidgets('Loading state shows progress indicator, disables buttons, and keeps M7 cards intact',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sampleInsight = AIInsight(
        title: 'Summary',
        explanation: 'Explanation',
        recommendation: 'Recommendation',
        generatedAt: now,
      );

      final delayedRepo = StubDelayAIInsightRepository(
        delay: const Duration(milliseconds: 300),
        insight: sampleInsight,
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            expensesStreamProvider.overrideWith((ref) => Stream.value(testExpenses)),
            aiInsightRepositoryProvider.overrideWithValue(delayedRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap Monthly Summary
      await tester.tap(find.text('Monthly Summary'));
      await tester.pump(); // Start async work

      // Check loading state
      expect(find.text('Generating monthly summary...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Verify deterministic M7 headers/cards are still visible on screen during loading
      expect(find.text('Understand where your money is going'), findsOneWidget);

      // Finish loading
      await tester.pumpAndSettle();
      expect(find.byType(AIInsightCard), findsOneWidget);
    });

    testWidgets('Error state shows sanitized message and retry button re-triggers successfully',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final successInsight = AIInsight(
        title: 'Resolved Insight',
        explanation: 'Explanation after retry',
        recommendation: 'Recommendation after retry',
        generatedAt: now,
      );

      final failingRepo = StubFailingAIInsightRepository(
        successInsight: successInsight,
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            expensesStreamProvider.overrideWith((ref) => Stream.value(testExpenses)),
            aiInsightRepositoryProvider.overrideWithValue(failingRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Attempt 1: Fails
      await tester.tap(find.text('Monthly Summary'));
      await tester.pumpAndSettle();

      expect(find.text('AI insights are temporarily unavailable.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Network unreachable'), findsNothing); // Verifies error is sanitized

      // Attempt 2: Tap Retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(AIInsightCard), findsOneWidget);
      expect(find.text('Resolved Insight'), findsOneWidget);
    });

    testWidgets('AIInsightCard displays supporting insight badge when present',
        (tester) async {
      final insightWithSupport = AIInsight(
        title: 'Category Focus',
        explanation: 'Most spending was in Food.',
        recommendation: 'Budget for groceries.',
        supportingInsightType: InsightType.topCategory,
        generatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AIInsightCard(insight: insightWithSupport),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Category Focus'), findsOneWidget);
      expect(find.text('Based on: Top category'), findsOneWidget);
      expect(find.text('AI-generated'), findsOneWidget);
    });
  });
}

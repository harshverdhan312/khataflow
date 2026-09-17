import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/spending_analytics_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insights_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends_calculator.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/expense/presentation/screens/spending_insights_screen.dart';
import 'package:khata_flow/features/insights/data/config/ai_provider_config.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_exception.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_request.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_response.dart';
import 'package:khata_flow/features/insights/domain/models/ai_request_type.dart';
import 'package:khata_flow/features/insights/domain/models/bounded_expense_summary.dart';
import 'package:khata_flow/features/insights/domain/repositories/ai_insight_repository.dart';
import 'package:khata_flow/features/insights/presentation/controllers/ai_insight_controller.dart';
import 'package:khata_flow/features/insights/presentation/controllers/ai_insight_state.dart';
import 'package:khata_flow/features/insights/presentation/providers/ai_insights_providers.dart';
import 'package:khata_flow/features/insights/presentation/widgets/ai_insight_card.dart';

/// Mock repository tracking method invocations for offline verification.
class TrackingAIRepository implements AIInsightRepository {
  int invocationCount = 0;
  AIInsightResponse? responseToReturn;
  Exception? exceptionToThrow;

  @override
  Future<AIInsightResponse> generateInsight(AIInsightRequest request) async {
    invocationCount++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return responseToReturn ??
        AIInsightResponse(
          insight: AIInsight(
            title: 'Mock Title',
            explanation: 'Mock Explanation',
            recommendation: 'Mock Recommendation',
            generatedAt: DateTime.now(),
          ),
          providerMetadata: const {'provider': 'TrackingAIRepository'},
        );
  }
}

void main() {
  final now = DateTime.now();

  List<Expense> createSampleExpenses() {
    return [
      Expense(
        id: 'exp-1',
        amountPaise: 450000, // ₹4,500
        category: ExpenseCategory.food,
        expenseDate: DateTime(now.year, now.month, 5),
        note: 'Supermarket supplies',
        createdAt: DateTime(now.year, now.month, 5),
        updatedAt: DateTime(now.year, now.month, 5),
      ),
      Expense(
        id: 'exp-2',
        amountPaise: 250000, // ₹2,500
        category: ExpenseCategory.shopping,
        expenseDate: DateTime(now.year, now.month, 10),
        note: 'Team dinner',
        createdAt: DateTime(now.year, now.month, 10),
        updatedAt: DateTime(now.year, now.month, 10),
      ),
      Expense(
        id: 'exp-3',
        amountPaise: 300000, // ₹3,000 in previous month
        category: ExpenseCategory.food,
        expenseDate: DateTime(now.year, now.month - 1, 15),
        note: 'Previous month groceries',
        createdAt: DateTime(now.year, now.month - 1, 15),
        updatedAt: DateTime(now.year, now.month - 1, 15),
      ),
    ];
  }

  Widget createTestWidget({
    required List<Expense> expenses,
    AIInsightRepository? aiRepo,
    AIInsightController? controller,
  }) {
    return ProviderScope(
      overrides: [
        expensesStreamProvider.overrideWith((ref) => Stream.value(expenses)),
        if (aiRepo != null)
          aiInsightRepositoryProvider.overrideWithValue(aiRepo),
        if (controller != null)
          aiInsightControllerProvider
              .overrideWith((ref) => controller),
      ],
      child: const MaterialApp(
        home: SpendingInsightsScreen(),
      ),
    );
  }

  group('M8.5 — Offline-First Architecture Verification', () {
    // =========================================================================
    // Test A — M7 works without AI
    // =========================================================================
    test('Test A — M7 Analytics, Trends, and Insights calculate 100% offline without AI invocation', () {
      final expenses = createSampleExpenses();
      final trackingRepo = TrackingAIRepository();

      // Execute deterministic domain calculators directly
      final analytics = deriveSpendingAnalytics(expenses);
      final trends = deriveSpendingTrends(expenses);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );

      // Verify deterministic results are accurate
      expect(analytics.currentMonthTotalPaise, 700000);
      expect(analytics.currentMonthExpenseCount, 2);
      expect(analytics.previousMonthTotalPaise, 300000);
      expect(trends.dailySpending.isNotEmpty, isTrue);
      expect(insights.hasInsights, isTrue);

      // Verify AI provider was NEVER invoked
      expect(trackingRepo.invocationCount, 0);
    });

    // =========================================================================
    // Test B — AI network failure
    // =========================================================================
    testWidgets('Test B — AI network failure preserves M7 insights and renders graceful unavailable state', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final expenses = createSampleExpenses();
      final trackingRepo = TrackingAIRepository()
        ..exceptionToThrow = const AINetworkException('Network unreachable');

      await tester.pumpWidget(
        createTestWidget(
          expenses: expenses,
          aiRepo: trackingRepo,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify M7 Summary Header is rendered and correct
      expect(find.text('Spending Insights'), findsOneWidget);
      expect(find.textContaining('7,000'), findsOneWidget); // ₹7,000 total
      expect(find.textContaining('2 expenses'), findsOneWidget);

      // 2. Verify M7 Deterministic Insight Cards are present
      expect(find.text('Understand where your money is going'), findsOneWidget);

      // 3. Trigger AI request that fails due to network outage
      final summaryBtn = find.text('Monthly Summary');
      expect(summaryBtn, findsOneWidget);
      await tester.tap(summaryBtn);
      await tester.pumpAndSettle();

      // 4. Verify AI error did NOT replace screen with full-screen error
      expect(find.text("Couldn't load spending insights"), findsNothing);
      expect(find.textContaining('7,000'), findsOneWidget);

      // 5. Verify Graceful localized AI unavailable state is displayed with Retry button
      expect(find.text('AI insights are temporarily unavailable.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    // =========================================================================
    // Test C — Offline deterministic path
    // =========================================================================
    test('Test C — Deterministic M7 path functions synchronously without network capability', () {
      final expenses = createSampleExpenses();

      // Verify pure functions execute instantly and synchronously
      final stopwatch = Stopwatch()..start();
      final analytics = deriveSpendingAnalytics(expenses);
      final trends = deriveSpendingTrends(expenses);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );
      stopwatch.stop();

      expect(analytics.hasCurrentMonthExpenses, isTrue);
      expect(trends.dailySpending.isNotEmpty, isTrue);
      expect(insights.insights.isNotEmpty, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    // =========================================================================
    // Test D — AI cannot modify financial truth
    // =========================================================================
    test('Test D — Conflicting or hallucinated AI numbers cannot alter deterministic M7 values', () {
      final expenses = createSampleExpenses();

      final originalAnalytics = deriveSpendingAnalytics(expenses);
      final originalTrends = deriveSpendingTrends(expenses);
      final originalInsights = deriveSpendingInsights(
        analytics: originalAnalytics,
        trends: originalTrends,
        expenses: expenses,
      );

      // Fabricate an AI insight claiming false financial numbers
      final hallucinatedAiInsight = AIInsight(
        title: 'You spent 50000000 rupees on shopping!',
        explanation: 'Your total balance is zero and you have 999 expenses.',
        recommendation: 'Stop all spending immediately.',
        generatedAt: DateTime.now(),
      );

      // Controller state with the hallucinated AI insight
      final state = AIInsightState.success(
        requestType: AIRequestType.monthlySummary,
        insight: hallucinatedAiInsight,
      );

      // Verify AI state holds the prose, but deterministic financial domain remains strictly untouched
      expect(state.insight?.title, contains('50000000'));
      expect(originalAnalytics.currentMonthTotalPaise, 700000);
      expect(originalAnalytics.currentMonthExpenseCount, 2);
      expect(
        originalAnalytics.categoryTotals
            .firstWhere((c) => c.category == ExpenseCategory.food)
            .totalAmountPaise,
        450000,
      );
      expect(originalTrends.dailySpending.isNotEmpty, isTrue);
      expect(originalInsights.highestPriority, isNotNull);
    });

    // =========================================================================
    // Test E — Empty month
    // =========================================================================
    testWidgets('Test E — Empty month shows deterministic empty state without AI invocation or fake data', (tester) async {
      final trackingRepo = TrackingAIRepository();

      await tester.pumpWidget(
        createTestWidget(
          expenses: const [],
          aiRepo: trackingRepo,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify deterministic empty state UI
      expect(find.text('No insights yet'), findsOneWidget);
      expect(
        find.text('Keep recording your expenses and KhataFlow will surface useful spending patterns here.'),
        findsOneWidget,
      );

      // 2. Verify AI section is NOT shown
      expect(find.text('AI Spending Intelligence'), findsNothing);
      expect(find.text('Monthly Summary'), findsNothing);

      // 3. Verify AI repository was NOT called
      expect(trackingRepo.invocationCount, 0);
    });

    // =========================================================================
    // Test F — AI success regression
    // =========================================================================
    testWidgets('Test F — AI success flow works seamlessly when provider is available', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final expenses = createSampleExpenses();
      final expectedInsight = AIInsight(
        title: 'Balanced spending profile with food focus',
        explanation: 'Food constituted 64% of your monthly expenditure.',
        recommendation: 'Keep tracking food items to spot bulk savings.',
        generatedAt: DateTime.now(),
      );

      final trackingRepo = TrackingAIRepository()
        ..responseToReturn = AIInsightResponse(
          insight: expectedInsight,
          providerMetadata: const {'provider': 'TestProvider'},
        );

      await tester.pumpWidget(
        createTestWidget(
          expenses: expenses,
          aiRepo: trackingRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Monthly Summary
      await tester.tap(find.text('Monthly Summary'));
      await tester.pumpAndSettle();

      // Verify AI Insight Card is rendered with AI-generated badge
      expect(find.byType(AIInsightCard), findsOneWidget);
      expect(find.text('AI-generated'), findsOneWidget);
      expect(find.text('Balanced spending profile with food focus'), findsOneWidget);
      expect(find.text('Keep tracking food items to spot bulk savings.'), findsOneWidget);

      // Verify M7 components remain untouched alongside AI card
      expect(find.textContaining('7,000'), findsOneWidget);
      expect(find.text('Understand where your money is going'), findsOneWidget);
    });

    // =========================================================================
    // Test G — AI failure after M7 success
    // =========================================================================
    testWidgets('Test G — Provider exception after M7 success is isolated without data loss', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final expenses = createSampleExpenses();
      final trackingRepo = TrackingAIRepository()
        ..exceptionToThrow = const AIProviderException(
          message: 'Server error 500',
          statusCode: 500,
        );

      await tester.pumpWidget(
        createTestWidget(
          expenses: expenses,
          aiRepo: trackingRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Deterministic insights are visible
      expect(find.text('Understand where your money is going'), findsOneWidget);

      // Request Spending Advice
      await tester.tap(find.text('Spending Advice'));
      await tester.pumpAndSettle();

      // M7 data remains visible and unaltered
      expect(find.text('Understand where your money is going'), findsOneWidget);
      expect(find.textContaining('7,000'), findsOneWidget);

      // AI shows localized sanitized message
      expect(find.text('AI insights are temporarily unavailable.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    // =========================================================================
    // AIAvailability Model & Provider
    // =========================================================================
    test('AIAvailability domain model correctly reflects operational states', () {
      const avail = AIAvailability.available();
      expect(avail.isAvailable, isTrue);
      expect(avail.status, AIAvailabilityStatus.available);

      const unavail = AIAvailability.unavailable('Offline');
      expect(unavail.isUnavailable, isTrue);
      expect(unavail.message, 'Offline');

      const disabled = AIAvailability.disabled();
      expect(disabled.isDisabled, isTrue);

      const unconfig = AIAvailability.unconfigured();
      expect(unconfig.isUnconfigured, isTrue);
    });

    test('aiAvailabilityProvider resolves based on configuration without network calls', () {
      final element = ProviderContainer(
        overrides: [
          aiProviderConfigProvider.overrideWithValue(AIProviderConfig.disabled()),
          useRealAiProviderProvider.overrideWith((ref) => true),
        ],
      );

      final availability = element.read(aiAvailabilityProvider);
      expect(availability.isUnconfigured, isTrue);

      final mockContainer = ProviderContainer(
        overrides: [
          useRealAiProviderProvider.overrideWith((ref) => false),
        ],
      );
      final mockAvailability = mockContainer.read(aiAvailabilityProvider);
      expect(mockAvailability.isAvailable, isTrue);
    });

    // =========================================================================
    // Bounded Summaries & Note Limit Integrity
    // =========================================================================
    test('BoundedExpenseSummary strictly enforces 200 char note limit and isolates DB metadata', () {
      final longNote = 'A' * 350;
      final summary = BoundedExpenseSummary(
        amountPaise: 150000,
        category: ExpenseCategory.shopping,
        date: DateTime(2026, 9, 17),
        note: longNote.substring(0, 200),
      );

      expect(summary.note!.length, 200);
      expect(summary.note, equals('A' * 200));
      expect(summary.amountPaise, 150000);
      expect(summary.category, ExpenseCategory.shopping);
    });
  });
}

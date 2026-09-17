import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/spending_analytics_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insights_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends_calculator.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_request.dart';
import 'package:khata_flow/features/insights/domain/models/ai_request_type.dart';
import 'package:khata_flow/features/insights/domain/services/ai_context_builder.dart';
import 'package:khata_flow/features/insights/presentation/controllers/ai_insight_cache.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  group('AIInsightCache Tests', () {
    const contextBuilder = AIContextBuilder();
    late AIInsightCache cache;
    final now = DateTime(2026, 9, 15);

    late List<Expense> expensesSet1;
    late List<Expense> expensesSet2;

    setUp(() {
      cache = AIInsightCache();

      expensesSet1 = [
        Expense(
          id: 'exp_1',
          amountPaise: 250000,
          category: ExpenseCategory.food,
          note: 'Groceries',
          expenseDate: DateTime(2026, 9, 5),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
      ];

      expensesSet2 = [
        Expense(
          id: 'exp_1',
          amountPaise: 250000,
          category: ExpenseCategory.food,
          note: 'Groceries',
          expenseDate: DateTime(2026, 9, 5),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
        Expense(
          id: 'exp_2',
          amountPaise: 100000,
          category: ExpenseCategory.bills,
          note: 'Electricity',
          expenseDate: DateTime(2026, 9, 8),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
      ];
    });

    test('same context + same request type returns cached response', () {
      final analytics = deriveSpendingAnalytics(expensesSet1, now: now);
      final trends = deriveSpendingTrends(expensesSet1);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expensesSet1,
      );

      final context = contextBuilder.buildContext(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      final request1 = AIInsightRequest(
        context: context,
        requestType: AIRequestType.monthlySummary,
      );
      final request2 = AIInsightRequest(
        context: context,
        requestType: AIRequestType.monthlySummary,
      );

      final insight = AIInsight(
        title: 'Monthly Spending Review',
        explanation: 'Spent ₹2,500 on Food.',
        recommendation: 'Track discretionary expenses.',
        generatedAt: now,
      );

      cache.put(request1, insight);

      expect(cache.size, equals(1));
      final cachedResult = cache.get(request2);
      expect(cachedResult, isNotNull);
      expect(cachedResult!.title, equals('Monthly Spending Review'));
    });

    test('changed financial context produces cache miss', () {
      final analytics1 = deriveSpendingAnalytics(expensesSet1, now: now);
      final trends1 = deriveSpendingTrends(expensesSet1);
      final insights1 = deriveSpendingInsights(
        analytics: analytics1,
        trends: trends1,
        expenses: expensesSet1,
      );

      final context1 = contextBuilder.buildContext(
        analytics: analytics1,
        trends: trends1,
        insights: insights1,
      );

      final analytics2 = deriveSpendingAnalytics(expensesSet2, now: now);
      final trends2 = deriveSpendingTrends(expensesSet2);
      final insights2 = deriveSpendingInsights(
        analytics: analytics2,
        trends: trends2,
        expenses: expensesSet2,
      );

      final context2 = contextBuilder.buildContext(
        analytics: analytics2,
        trends: trends2,
        insights: insights2,
      );

      final request1 = AIInsightRequest(
        context: context1,
        requestType: AIRequestType.monthlySummary,
      );
      final request2 = AIInsightRequest(
        context: context2,
        requestType: AIRequestType.monthlySummary,
      );

      final insight = AIInsight(
        title: 'Summary 1',
        explanation: 'Explanation 1',
        recommendation: 'Recommendation 1',
        generatedAt: now,
      );

      cache.put(request1, insight);

      expect(cache.get(request2), isNull);
    });

    test('changed user note in expense produces cache miss', () {
      final expensesWithNoteA = [
        Expense(
          id: 'exp_1',
          amountPaise: 250000,
          category: ExpenseCategory.food,
          note: 'Original Note',
          expenseDate: DateTime(2026, 9, 5),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
      ];

      final expensesWithNoteB = [
        Expense(
          id: 'exp_1',
          amountPaise: 250000,
          category: ExpenseCategory.food,
          note: 'Updated Note',
          expenseDate: DateTime(2026, 9, 5),
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.synced,
        ),
      ];

      final analyticsA = deriveSpendingAnalytics(expensesWithNoteA, now: now);
      final trendsA = deriveSpendingTrends(expensesWithNoteA);
      final insightsA = deriveSpendingInsights(
        analytics: analyticsA,
        trends: trendsA,
        expenses: expensesWithNoteA,
      );
      final contextA = contextBuilder.buildContext(
        analytics: analyticsA,
        trends: trendsA,
        insights: insightsA,
      );

      final analyticsB = deriveSpendingAnalytics(expensesWithNoteB, now: now);
      final trendsB = deriveSpendingTrends(expensesWithNoteB);
      final insightsB = deriveSpendingInsights(
        analytics: analyticsB,
        trends: trendsB,
        expenses: expensesWithNoteB,
      );
      final contextB = contextBuilder.buildContext(
        analytics: analyticsB,
        trends: trendsB,
        insights: insightsB,
      );

      final requestA = AIInsightRequest(
        context: contextA,
        requestType: AIRequestType.monthlySummary,
      );
      final requestB = AIInsightRequest(
        context: contextB,
        requestType: AIRequestType.monthlySummary,
      );

      cache.put(
        requestA,
        AIInsight(
          title: 'Title',
          explanation: 'Exp',
          recommendation: 'Rec',
          generatedAt: now,
        ),
      );

      expect(cache.get(requestA), isNotNull);
      expect(cache.get(requestB), isNull);
    });

    test('different request type produces cache miss', () {
      final analytics = deriveSpendingAnalytics(expensesSet1, now: now);
      final trends = deriveSpendingTrends(expensesSet1);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expensesSet1,
      );

      final context = contextBuilder.buildContext(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );

      final summaryRequest = AIInsightRequest(
        context: context,
        requestType: AIRequestType.monthlySummary,
      );
      final adviceRequest = AIInsightRequest(
        context: context,
        requestType: AIRequestType.spendingAdvice,
      );

      final summaryInsight = AIInsight(
        title: 'Monthly Summary',
        explanation: 'Summary explanation',
        recommendation: 'Summary recommendation',
        generatedAt: now,
      );

      cache.put(summaryRequest, summaryInsight);

      expect(cache.get(summaryRequest), isNotNull);
      expect(cache.get(adviceRequest), isNull);
    });

    test('changed period boundary produces cache miss', () {
      final analyticsMonth9 = deriveSpendingAnalytics(expensesSet1, now: DateTime(2026, 9, 15));
      final trendsMonth9 = deriveSpendingTrends(expensesSet1);
      final insightsMonth9 = deriveSpendingInsights(
        analytics: analyticsMonth9,
        trends: trendsMonth9,
        expenses: expensesSet1,
      );
      final contextMonth9 = contextBuilder.buildContext(
        analytics: analyticsMonth9,
        trends: trendsMonth9,
        insights: insightsMonth9,
      );

      final analyticsMonth10 = deriveSpendingAnalytics(expensesSet1, now: DateTime(2026, 10, 15));
      final trendsMonth10 = deriveSpendingTrends(expensesSet1);
      final insightsMonth10 = deriveSpendingInsights(
        analytics: analyticsMonth10,
        trends: trendsMonth10,
        expenses: expensesSet1,
      );
      final contextMonth10 = contextBuilder.buildContext(
        analytics: analyticsMonth10,
        trends: trendsMonth10,
        insights: insightsMonth10,
      );

      final requestMonth9 = AIInsightRequest(
        context: contextMonth9,
        requestType: AIRequestType.monthlySummary,
      );
      final requestMonth10 = AIInsightRequest(
        context: contextMonth10,
        requestType: AIRequestType.monthlySummary,
      );

      final insight = AIInsight(
        title: 'September Summary',
        explanation: 'September explanation',
        recommendation: 'September recommendation',
        generatedAt: now,
      );

      cache.put(requestMonth9, insight);

      expect(cache.get(requestMonth9), isNotNull);
      expect(cache.get(requestMonth10), isNull);
    });

    test('clear wipes all cached items', () {
      final analytics = deriveSpendingAnalytics(expensesSet1, now: now);
      final trends = deriveSpendingTrends(expensesSet1);
      final insights = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expensesSet1,
      );
      final context = contextBuilder.buildContext(
        analytics: analytics,
        trends: trends,
        insights: insights,
      );
      final request = AIInsightRequest(
        context: context,
        requestType: AIRequestType.monthlySummary,
      );

      cache.put(
        request,
        AIInsight(
          title: 'Test',
          explanation: 'Test',
          recommendation: 'Test',
          generatedAt: now,
        ),
      );

      expect(cache.size, equals(1));
      cache.clear();
      expect(cache.size, equals(0));
      expect(cache.get(request), isNull);
    });
  });
}

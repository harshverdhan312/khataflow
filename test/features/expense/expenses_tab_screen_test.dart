import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/category_spending.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insight.dart';
import 'package:khata_flow/features/expense/presentation/add_expense_sheet.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/expense/presentation/providers/spending_insights_provider.dart';
import 'package:khata_flow/features/expense/presentation/screens/expenses_tab_screen.dart';
import 'package:khata_flow/features/expense/presentation/widgets/category_spending_chart.dart';
import 'package:khata_flow/features/expense/presentation/widgets/spending_trend_chart.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight.dart';
import 'package:khata_flow/features/insights/domain/models/ai_request_type.dart';
import 'package:khata_flow/features/insights/presentation/controllers/ai_insight_controller.dart';
import 'package:khata_flow/features/insights/presentation/controllers/ai_insight_state.dart';
import 'package:khata_flow/features/insights/presentation/providers/ai_insights_providers.dart';
import 'package:khata_flow/features/insights/presentation/widgets/ai_insight_card.dart';

void main() {
  group('ExpensesTabScreen Tests', () {
    testWidgets('renders empty state when there are no expenses', (tester) async {
      final container = ProviderContainer(
        overrides: [
          expensesStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ExpensesTabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No expenses recorded yet'), findsOneWidget);
      expect(find.text('Tap the microphone on Home or the + button below to log an expense.'), findsOneWidget);
    });

    testWidgets('renders spending hero, intelligence, and recent expenses with real data', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final sampleExpenses = [
        Expense(
          id: 'exp-1',
          amountPaise: 45000,
          category: ExpenseCategory.food,
          expenseDate: now,
          note: 'Groceries at supermart',
          createdAt: now,
          updatedAt: now,
        ),
        Expense(
          id: 'exp-2',
          amountPaise: 20000,
          category: ExpenseCategory.transport,
          expenseDate: now.subtract(const Duration(days: 1)),
          note: 'Metro recharge',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final sampleAnalytics = SpendingAnalytics(
        currentPeriodStart: DateTime(now.year, now.month, 1),
        currentPeriodEnd: DateTime(now.year, now.month + 1, 1),
        previousPeriodStart: DateTime(now.year, now.month - 1, 1),
        previousPeriodEnd: DateTime(now.year, now.month, 1),
        currentMonthTotalPaise: 65000,
        previousMonthTotalPaise: 50000,
        monthOverMonthChangePaise: 15000,
        currentMonthExpenseCount: 2,
        previousMonthExpenseCount: 2,
        monthOverMonthChangePercent: 12.5,
        recentExpenses: sampleExpenses,
        categoryTotals: const [
          CategorySpending(category: ExpenseCategory.food, totalAmountPaise: 45000),
          CategorySpending(category: ExpenseCategory.transport, totalAmountPaise: 20000),
        ],
      );

      final sampleTrends = const SpendingTrends(
        dailySpending: [],
        weeklySpending: [],
        monthlySpending: [],
        categoryTrends: [],
      );

      final sampleInsights = SpendingInsights(
        insights: [
          SpendingInsight(
            type: InsightType.topCategory,
            title: 'Top Category: Food & Dining',
            description: 'Food & Dining represents 69% of your spending this month.',
            priority: InsightPriority.high,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          expensesStreamProvider.overrideWith((ref) => Stream.value(sampleExpenses)),
          spendingAnalyticsProvider.overrideWith((ref) => AsyncValue.data(sampleAnalytics)),
          spendingTrendsProvider.overrideWith((ref) => AsyncValue.data(sampleTrends)),
          spendingInsightsProvider.overrideWith((ref) => AsyncValue.data(sampleInsights)),
          aiInsightControllerProvider.overrideWith(
            (ref) => _FakeAIInsightController(
              AIInsightState(
                status: AIInsightStatus.success,
                requestType: AIRequestType.monthlySummary,
                insight: AIInsight(
                  title: 'Food is your top category',
                  explanation: 'You spent ₹450 on food this month (69% of total spending).',
                  recommendation: 'Consider meal prepping to lower food expenses.',
                  generatedAt: now,
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ExpensesTabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hero Card
      expect(find.text('THIS MONTH'), findsOneWidget);
      expect(find.text('₹650'), findsOneWidget);
      expect(find.text('+12.5% vs last period'), findsOneWidget);

      // Spending Trend & Category Spending Charts
      expect(find.byType(SpendingTrendChart), findsOneWidget);
      expect(find.byType(CategorySpendingChart), findsOneWidget);
      expect(find.text('SPENDING TREND'), findsOneWidget);
      expect(find.text('CATEGORY SPENDING'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);
      expect(find.text('₹450'), findsWidgets);
      expect(find.text('Transport'), findsWidgets);
      expect(find.text('₹200'), findsWidgets);

      // AI Spending Intelligence section
      expect(find.text('AI Spending Intelligence'), findsOneWidget);
      expect(find.byType(AIInsightCard), findsOneWidget);
      expect(find.text('Food is your top category'), findsOneWidget);
      expect(find.text('You spent ₹450 on food this month (69% of total spending).'), findsOneWidget);

      // Recent Expenses
      expect(find.text('Recent Expenses'), findsOneWidget);
      expect(find.text('Groceries at supermart'), findsOneWidget);
      expect(find.text('Metro recharge'), findsOneWidget);
    });

    testWidgets('tapping FAB opens AddExpenseSheet modal bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          expensesStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ExpensesTabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find FAB
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Verify AddExpenseSheet opened
      expect(find.byType(AddExpenseSheet), findsOneWidget);
      expect(find.text('AMOUNT'), findsOneWidget);
      expect(find.text('CATEGORY'), findsOneWidget);
      expect(find.text('Save Expense'), findsOneWidget);
    });
  });
}


class _FakeAIInsightController extends StateNotifier<AIInsightState>
    implements AIInsightController {
  _FakeAIInsightController(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

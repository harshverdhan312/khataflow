import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/category_spending.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trend_point.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/expense/presentation/screens/expenses_tab_screen.dart';
import 'package:khata_flow/features/expense/presentation/widgets/category_spending_chart.dart';
import 'package:khata_flow/features/expense/presentation/widgets/spending_trend_chart.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  group('SpendingTrendChart Widget Tests', () {
    testWidgets('renders trend chart with daily spending points and mode selector', (tester) async {
      final dailyPoints = [
        SpendingTrendPoint(
          periodStart: DateTime(2026, 9, 1),
          periodEnd: DateTime(2026, 9, 2),
          totalAmountPaise: 50000, // ₹500
        ),
        SpendingTrendPoint(
          periodStart: DateTime(2026, 9, 5),
          periodEnd: DateTime(2026, 9, 6),
          totalAmountPaise: 120000, // ₹1,200
        ),
        SpendingTrendPoint(
          periodStart: DateTime(2026, 9, 10),
          periodEnd: DateTime(2026, 9, 11),
          totalAmountPaise: 30000, // ₹300
        ),
      ];

      final trends = SpendingTrends(
        dailySpending: dailyPoints,
        weeklySpending: [
          SpendingTrendPoint(
            periodStart: DateTime(2026, 9, 1),
            periodEnd: DateTime(2026, 9, 8),
            totalAmountPaise: 170000,
          ),
          SpendingTrendPoint(
            periodStart: DateTime(2026, 9, 8),
            periodEnd: DateTime(2026, 9, 15),
            totalAmountPaise: 30000,
          ),
        ],
        monthlySpending: [
          SpendingTrendPoint(
            periodStart: DateTime(2026, 9, 1),
            periodEnd: DateTime(2026, 10, 1),
            totalAmountPaise: 200000,
          ),
        ],
        categoryTrends: const [],
        highestSpendingDay: HighestSpendingDay(
          date: DateTime(2026, 9, 5),
          totalAmountPaise: 120000,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpendingTrendChart(trends: trends),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & modes
      expect(find.text('SPENDING TREND'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);

      // Verify peak info
      expect(find.text('Peak: ₹1,200'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Switch to Weekly mode
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();

      expect(find.text('Peak: ₹1,700'), findsOneWidget);

      // Switch to Monthly mode
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      expect(find.text('Peak: ₹2,000'), findsOneWidget);
    });

    testWidgets('renders empty trend state when all points have 0 spending', (tester) async {
      const trends = SpendingTrends(
        dailySpending: [],
        weeklySpending: [],
        monthlySpending: [],
        categoryTrends: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpendingTrendChart(trends: trends),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SPENDING TREND'), findsOneWidget);
      expect(find.text('No spending trend recorded for this period'), findsOneWidget);
    });
  });

  group('CategorySpendingChart Widget Tests', () {
    testWidgets('renders horizontal bars with category names, amounts, and percentages', (tester) async {
      const categoryTotals = [
        CategorySpending(category: ExpenseCategory.food, totalAmountPaise: 520000), // ₹5,200 (52%)
        CategorySpending(category: ExpenseCategory.transport, totalAmountPaise: 280000), // ₹2,800 (28%)
        CategorySpending(category: ExpenseCategory.shopping, totalAmountPaise: 200000), // ₹2,000 (20%)
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategorySpendingChart(categoryTotals: categoryTotals),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CATEGORY SPENDING'), findsOneWidget);
      expect(find.text('3 categories'), findsOneWidget);

      // Category names
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);

      // Formatted amounts
      expect(find.text('₹5,200'), findsOneWidget);
      expect(find.text('₹2,800'), findsOneWidget);
      expect(find.text('₹2,000'), findsOneWidget);

      // Percentages
      expect(find.text('52%'), findsOneWidget);
      expect(find.text('28%'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    });

    testWidgets('renders empty category state when categoryTotals is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategorySpendingChart(categoryTotals: []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No category spending recorded yet'), findsOneWidget);
    });
  });

  group('Expenses Charts Reactive Integration Tests', () {
    testWidgets('ExpensesTabScreen updates SpendingTrendChart & CategorySpendingChart reactively upon stream mutations', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final expenseStreamController = StreamController<List<Expense>>.broadcast();
      addTearDown(expenseStreamController.close);

      final container = ProviderContainer(
        overrides: [
          expensesStreamProvider.overrideWith((ref) => expenseStreamController.stream),
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

      // Initial empty state
      expenseStreamController.add([]);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('No expenses recorded yet'), findsOneWidget);

      final now = DateTime.now();

      // 1. Create: ₹300 Food expense emitted
      final created = Expense(
        id: 'exp-1',
        amountPaise: 30000,
        category: ExpenseCategory.food,
        expenseDate: now,
        note: 'Burger lunch',
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.synced,
      );

      expenseStreamController.add([created]);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(SpendingTrendChart), findsOneWidget);
      expect(find.byType(CategorySpendingChart), findsOneWidget);
      expect(find.text('SPENDING TREND'), findsOneWidget);
      expect(find.text('CATEGORY SPENDING'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);
      expect(find.text('₹300'), findsWidgets);

      // 2. Edit: Update to ₹750 Transport expense
      final updated = Expense(
        id: 'exp-1',
        amountPaise: 75000,
        category: ExpenseCategory.transport,
        expenseDate: now,
        note: 'Train pass',
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.synced,
      );

      expenseStreamController.add([updated]);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Transport'), findsWidgets);
      expect(find.text('₹750'), findsWidgets);

      // 3. Delete: Emit empty list
      expenseStreamController.add([]);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('No expenses recorded yet'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      container.dispose();
    });
  });
}

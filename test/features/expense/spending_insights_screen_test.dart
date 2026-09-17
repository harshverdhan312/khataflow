import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/expense/presentation/screens/spending_insights_screen.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  Expense createTestExpense({
    required String id,
    required int amountPaise,
    required ExpenseCategory category,
    required DateTime expenseDate,
  }) {
    return Expense(
      id: id,
      amountPaise: amountPaise,
      category: category,
      expenseDate: expenseDate,
      createdAt: expenseDate,
      updatedAt: expenseDate,
      syncStatus: SyncStatus.synced,
    );
  }

  Widget createTestWidget({required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: SpendingInsightsScreen(),
      ),
    );
  }

  group('SpendingInsightsScreen Widget Tests', () {
    testWidgets('Renders empty state when there are no expenses or insights', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            expensesStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spending Insights'), findsOneWidget);
      expect(find.text('No insights yet'), findsOneWidget);
      expect(
        find.text(
          'Keep recording your expenses and KhataFlow will surface useful spending patterns here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Renders summary header and structured insight cards in M7.3 order', (tester) async {
      final now = DateTime.now();
      final currentMonthDate = DateTime(now.year, now.month, 5);

      final expenses = [
        createTestExpense(
          id: 'exp-1',
          amountPaise: 900000, // ₹9,000 on Food (> 50% concentration -> High priority)
          category: ExpenseCategory.food,
          expenseDate: currentMonthDate,
        ),
        createTestExpense(
          id: 'exp-2',
          amountPaise: 100000, // ₹1,000 on Transport
          category: ExpenseCategory.transport,
          expenseDate: currentMonthDate,
        ),
      ];

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            expensesStreamProvider.overrideWith((ref) => Stream.value(expenses)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spending Insights'), findsOneWidget);
      expect(find.text('Understand where your money is going'), findsOneWidget);

      // Summary Header (Total ₹10,000)
      expect(find.text('₹10,000'), findsAtLeastNWidgets(1));
      expect(find.text('2 expenses'), findsOneWidget);

      // Concentration Insight (High priority)
      expect(find.text('High Spending Concentration'), findsOneWidget);
      expect(
        find.text('More than half your spending was in Food.'),
        findsOneWidget,
      );

      // Top Category & Largest Expense cards
      expect(find.text('Top Category'), findsOneWidget);
      expect(find.text('Largest Expense'), findsOneWidget);
    });

    testWidgets('Renders error state with retry button when expenses stream errors', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            expensesStreamProvider.overrideWith(
              (ref) => Stream.error('Database connection failed'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load spending insights"), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}

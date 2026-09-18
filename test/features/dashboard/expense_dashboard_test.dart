import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:khata_flow/features/dashboard/domain/expense_dashboard_summary.dart';
import 'package:khata_flow/features/dashboard/presentation/dashboard_providers.dart';
import 'package:khata_flow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/merchant/presentation/merchant_providers.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  group('ExpenseDashboardSummary Domain Unit Tests', () {
    final referenceDate = DateTime(2026, 9, 15, 14, 30);

    test('calculates current month expenses and excludes previous/next month', () {
      final expenses = [
        Expense(
          id: 'exp_cur_1',
          amountPaise: 25000,
          category: ExpenseCategory.food,
          note: 'Team lunch',
          expenseDate: DateTime(2026, 9, 2),
          createdAt: DateTime(2026, 9, 2),
          updatedAt: DateTime(2026, 9, 2),
          syncStatus: SyncStatus.pending,
        ),
        Expense(
          id: 'exp_cur_2',
          amountPaise: 15050,
          category: ExpenseCategory.transport,
          note: 'Cab fare',
          expenseDate: DateTime(2026, 9, 14),
          createdAt: DateTime(2026, 9, 14),
          updatedAt: DateTime(2026, 9, 14),
          syncStatus: SyncStatus.pending,
        ),
        Expense(
          id: 'exp_prev',
          amountPaise: 80000,
          category: ExpenseCategory.bills,
          note: 'Electricity last month',
          expenseDate: DateTime(2026, 8, 31, 23, 59),
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
          syncStatus: SyncStatus.pending,
        ),
        Expense(
          id: 'exp_next',
          amountPaise: 50000,
          category: ExpenseCategory.shopping,
          note: 'Future event booking',
          expenseDate: DateTime(2026, 10, 1),
          createdAt: DateTime(2026, 9, 15),
          updatedAt: DateTime(2026, 9, 15),
          syncStatus: SyncStatus.pending,
        ),
      ];

      final summary = deriveExpenseDashboardSummary(expenses, referenceDate);

      expect(summary.totalAmountPaise, 40050); // 25000 + 15050
      expect(summary.currentMonthExpenseCount, 2);
      expect(summary.hasCurrentMonthExpenses, true);
      expect(summary.periodStart, DateTime(2026, 9, 1));
      expect(summary.periodEnd, DateTime(2026, 10, 1));
    });

    test('respects business expenseDate and ignores createdAt for spending period', () {
      final expenseCreatedTodayForLastMonth = Expense(
        id: 'exp_backdated',
        amountPaise: 99900,
        category: ExpenseCategory.shopping,
        note: 'Backdated shopping',
        expenseDate: DateTime(2026, 8, 20),
        createdAt: DateTime(2026, 9, 15), // Created today
        updatedAt: DateTime(2026, 9, 15),
        syncStatus: SyncStatus.pending,
      );

      final summary = deriveExpenseDashboardSummary(
        [expenseCreatedTodayForLastMonth],
        referenceDate,
      );

      expect(summary.totalAmountPaise, 0);
      expect(summary.currentMonthExpenseCount, 0);
      expect(summary.hasCurrentMonthExpenses, false);
      expect(summary.categoryBreakdown, isEmpty);
    });

    test('aggregates category spending with descending sort and secondary alphabetical tie-break', () {
      final expenses = [
        Expense(
          id: 'e1',
          amountPaise: 30000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 5),
          createdAt: DateTime(2026, 9, 5),
          updatedAt: DateTime(2026, 9, 5),
          syncStatus: SyncStatus.pending,
        ),
        Expense(
          id: 'e2',
          amountPaise: 20000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 6),
          createdAt: DateTime(2026, 9, 6),
          updatedAt: DateTime(2026, 9, 6),
          syncStatus: SyncStatus.pending,
        ),
        Expense(
          id: 'e3',
          amountPaise: 50000,
          category: ExpenseCategory.bills,
          expenseDate: DateTime(2026, 9, 7),
          createdAt: DateTime(2026, 9, 7),
          updatedAt: DateTime(2026, 9, 7),
          syncStatus: SyncStatus.pending,
        ),
        Expense(
          id: 'e4',
          amountPaise: 10000,
          category: ExpenseCategory.transport,
          expenseDate: DateTime(2026, 9, 8),
          createdAt: DateTime(2026, 9, 8),
          updatedAt: DateTime(2026, 9, 8),
          syncStatus: SyncStatus.pending,
        ),
      ];

      final summary = deriveExpenseDashboardSummary(expenses, referenceDate);

      expect(summary.categoryBreakdown.length, 3);
      expect(summary.categoryBreakdown[0].category, ExpenseCategory.bills);
      expect(summary.categoryBreakdown[0].totalAmountPaise, 50000);
      expect(summary.categoryBreakdown[1].category, ExpenseCategory.food);
      expect(summary.categoryBreakdown[1].totalAmountPaise, 50000);
      expect(summary.categoryBreakdown[2].category, ExpenseCategory.transport);
      expect(summary.categoryBreakdown[2].totalAmountPaise, 10000);
    });

    test('caps recentExpenses to exactly 5 items', () {
      final expenses = List.generate(
        10,
        (i) => Expense(
          id: 'exp_$i',
          amountPaise: (i + 1) * 1000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 10 - i),
          createdAt: DateTime(2026, 9, 10 - i),
          updatedAt: DateTime(2026, 9, 10 - i),
          syncStatus: SyncStatus.pending,
        ),
      );

      final summary = deriveExpenseDashboardSummary(expenses, referenceDate);
      expect(summary.recentExpenses.length, 5);
      expect(summary.recentExpenses.first.id, 'exp_0');
      expect(summary.recentExpenses.last.id, 'exp_4');
    });
  });

  group('DashboardScreen Clean Ledger Integration Tests', () {
    testWidgets('DashboardScreen does NOT render spending overview or expense sections', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardSummaryStreamProvider.overrideWith((ref) => Stream.value(
                  const DashboardSummary(
                    totalOutstandingPaise: 0,
                    merchantSummaries: [],
                  ),
                )),
            inactiveMerchantsStreamProvider.overrideWith((ref) => Stream.value([])),
            expensesStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Ledger tab should purely focus on Store tabs & dues, no expenses
      expect(find.text('Spending Overview'), findsNothing);
      expect(find.text('No expenses this month'), findsNothing);
      expect(find.text('View Expenses'), findsNothing);
      expect(find.text('Your Store Tabs'), findsOneWidget);
    });
  });
}


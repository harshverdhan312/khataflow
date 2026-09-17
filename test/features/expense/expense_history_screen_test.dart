import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khata_flow/core/utils/currency_formatter.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/presentation/expense_detail_sheet.dart';
import 'package:khata_flow/features/expense/presentation/expense_history_screen.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  group('ExpenseHistoryScreen Widget Tests', () {
    testWidgets('renders empty state when there are no expenses and navigates to add expense', (tester) async {
      bool openedAdd = false;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ExpenseHistoryScreen(),
          ),
          GoRoute(
            path: '/expense/add',
            builder: (context, state) {
              openedAdd = true;
              return const Scaffold(body: Text('Add Expense Screen'));
            },
          ),
        ],
      );

      final app = ProviderScope(
        overrides: [
          expensesStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('No expenses recorded yet'), findsOneWidget);
      expect(find.text('Add your personal expenses to track your spending locally.'), findsOneWidget);

      // Tap CTA Add Expense button
      final addButtons = find.text('Add Expense');
      expect(addButtons, findsOneWidget);
      await tester.tap(addButtons);
      await tester.pumpAndSettle();

      expect(openedAdd, isTrue);
    });

    testWidgets('renders loading state indicator', (tester) async {
      final app = ProviderScope(
        overrides: [
          expensesStreamProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: ExpenseHistoryScreen(),
        ),
      );

      await tester.pumpWidget(app);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders error state and handles retry', (tester) async {
      int fetchAttempts = 0;

      final app = ProviderScope(
        overrides: [
          expensesStreamProvider.overrideWith((ref) {
            fetchAttempts++;
            return Stream.error('Network/Database error');
          }),
        ],
        child: const MaterialApp(
          home: ExpenseHistoryScreen(),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Failed to load expenses'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(fetchAttempts, greaterThanOrEqualTo(1));
    });

    testWidgets('renders date grouped expenses with proper amounts, categories, notes and opens detail sheet', (tester) async {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day, 14, 30);
      final yesterdayDate = todayDate.subtract(const Duration(days: 1));

      final expense1 = Expense(
        id: 'exp_1',
        amountPaise: 35000,
        category: ExpenseCategory.food,
        note: 'Burger with friends',
        expenseDate: todayDate,
        createdAt: todayDate,
        updatedAt: todayDate,
        syncStatus: SyncStatus.pending,
      );

      final expense2 = Expense(
        id: 'exp_2',
        amountPaise: 12050,
        category: ExpenseCategory.transport,
        note: null,
        expenseDate: todayDate,
        createdAt: todayDate,
        updatedAt: todayDate,
        syncStatus: SyncStatus.pending,
      );

      final expense3 = Expense(
        id: 'exp_3',
        amountPaise: 50000,
        category: ExpenseCategory.bills,
        note: 'Electricity',
        expenseDate: yesterdayDate,
        createdAt: yesterdayDate,
        updatedAt: yesterdayDate,
        syncStatus: SyncStatus.pending,
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ExpenseHistoryScreen(),
          ),
        ],
      );

      final app = ProviderScope(
        overrides: [
          expensesStreamProvider.overrideWith((ref) => Stream.value([expense1, expense2, expense3])),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Verify date headers
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);

      // Verify category items & amounts
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Burger with friends'), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatPaise(35000)), findsOneWidget);

      expect(find.text('Transport'), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatPaise(12050)), findsOneWidget);

      expect(find.text('Bills'), findsOneWidget);
      expect(find.text('Electricity'), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatPaise(50000)), findsNWidgets(2)); // Day total header and card amount

      // Tap an expense to open detail sheet
      await tester.tap(find.text('Burger with friends'));
      await tester.pumpAndSettle();

      // Verify ExpenseDetailSheet is presented
      expect(find.byType(ExpenseDetailSheet), findsOneWidget);
      expect(find.text('Edit Expense'), findsOneWidget);
      expect(find.text('Delete Expense'), findsOneWidget);
    });
  });
}

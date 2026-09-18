import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/utils/currency_formatter.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/expense/presentation/screens/expenses_tab_screen.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  group('ExpensesTabScreen End-to-End Reactive Tests', () {
    testWidgets('ExpensesTabScreen reactively reflects Create -> Edit -> Delete without manual reload', (tester) async {
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

      // 1. Initial State: No expenses emitted
      expenseStreamController.add([]);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('No expenses recorded yet'), findsOneWidget);

      final now = DateTime.now();

      // 2. Create: ₹200 Food expense emitted via stream
      final createdExpense = Expense(
        id: 'exp_1',
        amountPaise: 20000,
        category: ExpenseCategory.food,
        note: 'Burger',
        expenseDate: now,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      );

      expenseStreamController.add([createdExpense]);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Expenses tab updates reactively to ₹200
      expect(find.text('No expenses recorded yet'), findsNothing);
      expect(find.text('THIS MONTH'), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatPaise(20000)), findsWidgets);
      expect(find.text('Burger'), findsOneWidget);

      // 3. Edit: Update ₹200 Food -> ₹500 Shopping emitted via stream
      final updatedExpense = Expense(
        id: 'exp_1',
        amountPaise: 50000,
        category: ExpenseCategory.shopping,
        note: 'Sneakers',
        expenseDate: now,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      );

      expenseStreamController.add([updatedExpense]);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Expenses tab updates reactively to ₹500 and Shopping
      expect(find.text(CurrencyFormatter.formatPaise(50000)), findsWidgets);
      expect(find.text('Sneakers'), findsOneWidget);
      expect(find.text('Shopping'), findsWidgets);

      // 4. Delete: Remove the expense (empty list emitted)
      expenseStreamController.add([]);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Expenses tab updates reactively back to empty state
      expect(find.text('No expenses recorded yet'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      container.dispose();
    });
  });
}


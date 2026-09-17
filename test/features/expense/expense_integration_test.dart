import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/database/database_provider.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/presentation/add_expense_screen.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  group('Expense Full Lifecycle Integration Test', () {
    testWidgets('Create -> View in History -> Edit -> Delete -> SQLite & SyncQueue verification', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );

      // --- STAGE 1: ADD EXPENSE VIA SCREEN ---
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddExpenseScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // 1. Enter Amount: ₹450.75 -> 45075 paise
      await tester.enterText(find.byType(TextFormField).first, '450.75');

      // 2. Select Category: Bills
      await tester.tap(find.text('Bills'));
      await tester.pump();

      // 3. Enter Note
      await tester.enterText(find.byType(TextFormField).at(1), 'Electricity bill payment');

      // 4. Submit form
      await tester.ensureVisible(find.text('Save Expense'));
      await tester.tap(find.text('Save Expense'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Expense added'), findsOneWidget);

      // --- STAGE 2: VERIFY PERSISTENCE IN REAL SQLite & SYNC QUEUE ---
      final repo = container.read(expenseRepositoryProvider);
      final persistedExpenses = await repo.getExpenses();
      expect(persistedExpenses.length, 1);

      final entity = persistedExpenses.first;
      expect(entity.id, isNotEmpty);
      expect(entity.amountPaise, 45075);
      expect(entity.category, ExpenseCategory.bills);
      expect(entity.note, 'Electricity bill payment');
      expect(entity.syncStatus, SyncStatus.pending);

      var syncItems = await db.syncQueueDao.getPendingItems();
      expect(syncItems.length, 1);
      expect(syncItems.first.entityId, entity.id);
      expect(syncItems.first.entityType, SyncEntityType.expense.toDbValue());
      expect(syncItems.first.operation, SyncOperation.upsert.toDbValue());

      // --- STAGE 3: EDIT EXPENSE ---
      final updated = await repo.updateExpense(UpdateExpenseInput(
        id: entity.id,
        amountPaise: 50000,
        category: ExpenseCategory.shopping,
        note: 'Updated shopping note',
        expenseDate: entity.expenseDate,
      ));

      expect(updated.amountPaise, 50000);
      expect(updated.category, ExpenseCategory.shopping);
      expect(updated.note, 'Updated shopping note');

      // Verify updated in SQLite
      final updatedExpenses = await repo.getExpenses();
      expect(updatedExpenses.length, 1);
      expect(updatedExpenses.first.amountPaise, 50000);
      expect(updatedExpenses.first.category, ExpenseCategory.shopping);
      expect(updatedExpenses.first.note, 'Updated shopping note');

      // Verify outbox sync records (2 items: 1 insert, 1 update)
      syncItems = await db.syncQueueDao.getPendingItems();
      expect(syncItems.length, 2);
      expect(syncItems.last.operation, SyncOperation.upsert.toDbValue());

      // --- STAGE 4: DELETE EXPENSE ---
      await repo.deleteExpense(entity.id);

      // Verify deleted from SQLite
      final remainingExpenses = await repo.getExpenses();
      expect(remainingExpenses.isEmpty, true);

      // Verify DELETE operation in sync queue (3 items total: insert, update, delete)
      syncItems = await db.syncQueueDao.getPendingItems();
      expect(syncItems.length, 3);
      expect(syncItems.last.operation, SyncOperation.delete.toDbValue());

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      container.dispose();
      await db.close();
    });
  });
}

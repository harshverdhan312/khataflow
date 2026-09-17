import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/errors/app_exceptions.dart';
import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/features/expense/data/expense_repository_impl.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  late AppDatabase db;
  late ExpenseRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ExpenseRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ExpenseRepositoryImpl Tests', () {
    test('creates expense of ₹250 (25000 paise) and enqueues atomic sync queue item', () async {
      final now = DateTime.now();
      final expenseDate = now.subtract(const Duration(days: 2));

      final input = CreateExpenseInput(
        amountPaise: 25000,
        category: ExpenseCategory.food,
        note: 'Lunch with colleagues',
        expenseDate: expenseDate,
      );

      final created = await repository.createExpense(input);

      expect(created.id, isNotEmpty);
      expect(created.amountPaise, 25000);
      expect(created.category, ExpenseCategory.food);
      expect(created.note, 'Lunch with colleagues');
      expect(created.expenseDate.millisecondsSinceEpoch, expenseDate.millisecondsSinceEpoch);
      expect(created.syncStatus, SyncStatus.pending);

      // Verify DB entity
      final fetched = await repository.getExpenseById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.amountPaise, 25000);
      expect(fetched.category, ExpenseCategory.food);

      // Verify Outbox SyncQueue
      final syncItems = await db.syncQueueDao.getPendingItems();
      expect(syncItems.length, 1);
      expect(syncItems.first.entityId, created.id);
      expect(syncItems.first.entityType, SyncEntityType.expense.toDbValue());
      expect(syncItems.first.operation, SyncOperation.upsert.toDbValue());
    });

    test('creates expense of ₹99.50 (9950 paise)', () async {
      final input = CreateExpenseInput(
        amountPaise: 9950,
        category: ExpenseCategory.transport,
        note: 'Bus fare',
        expenseDate: DateTime.now(),
      );

      final created = await repository.createExpense(input);
      expect(created.amountPaise, 9950);
      expect(created.category, ExpenseCategory.transport);
    });

    test('rejects zero amount', () async {
      final input = CreateExpenseInput(
        amountPaise: 0,
        category: ExpenseCategory.bills,
        expenseDate: DateTime.now(),
      );

      expect(
        () => repository.createExpense(input),
        throwsA(isA<InvalidAmountException>()),
      );
    });

    test('rejects negative amount', () async {
      final input = CreateExpenseInput(
        amountPaise: -5000,
        category: ExpenseCategory.entertainment,
        expenseDate: DateTime.now(),
      );

      expect(
        () => repository.createExpense(input),
        throwsA(isA<InvalidAmountException>()),
      );
    });

    test('works with optional null note or whitespace note', () async {
      final inputNull = CreateExpenseInput(
        amountPaise: 10000,
        category: ExpenseCategory.shopping,
        expenseDate: DateTime.now(),
      );

      final created1 = await repository.createExpense(inputNull);
      expect(created1.note, isNull);

      final inputWhitespace = CreateExpenseInput(
        amountPaise: 15000,
        category: ExpenseCategory.health,
        note: '   ',
        expenseDate: DateTime.now(),
      );

      final created2 = await repository.createExpense(inputWhitespace);
      expect(created2.note, isNull);
    });

    test('rejects note longer than 200 characters', () async {
      final longNote = 'A' * 201;
      final input = CreateExpenseInput(
        amountPaise: 5000,
        category: ExpenseCategory.other,
        note: longNote,
        expenseDate: DateTime.now(),
      );

      expect(
        () => repository.createExpense(input),
        throwsA(isA<ValidationException>()),
      );
    });

    test('preserves date independence where expenseDate != createdAt', () async {
      final pastExpenseDate = DateTime.utc(2025, 1, 15, 10, 30);
      final input = CreateExpenseInput(
        amountPaise: 30000,
        category: ExpenseCategory.education,
        expenseDate: pastExpenseDate,
      );

      final created = await repository.createExpense(input);

      expect(created.expenseDate.millisecondsSinceEpoch, pastExpenseDate.millisecondsSinceEpoch);
      expect(created.createdAt.millisecondsSinceEpoch, isNot(equals(pastExpenseDate.millisecondsSinceEpoch)));
    });

    test('updates expense and preserves createdAt while updating updatedAt and enqueuing sync', () async {
      final originalDate = DateTime.utc(2026, 3, 1, 12, 0);
      final created = await repository.createExpense(
        CreateExpenseInput(
          amountPaise: 20000,
          category: ExpenseCategory.food,
          note: 'Dinner',
          expenseDate: originalDate,
        ),
      );

      final initialCreatedAt = created.createdAt;
      final initialUpdatedAt = created.updatedAt;

      // Ensure some millisecond diff
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final newExpenseDate = DateTime.utc(2026, 3, 2, 14, 0);
      final updateInput = UpdateExpenseInput(
        id: created.id,
        amountPaise: 28000,
        category: ExpenseCategory.entertainment,
        note: 'Dinner and Movie',
        expenseDate: newExpenseDate,
      );

      final updated = await repository.updateExpense(updateInput);

      expect(updated.id, created.id);
      expect(updated.amountPaise, 28000);
      expect(updated.category, ExpenseCategory.entertainment);
      expect(updated.note, 'Dinner and Movie');
      expect(updated.expenseDate, newExpenseDate);
      expect(updated.createdAt.millisecondsSinceEpoch, initialCreatedAt.millisecondsSinceEpoch);
      expect(updated.updatedAt.millisecondsSinceEpoch, greaterThanOrEqualTo(initialUpdatedAt.millisecondsSinceEpoch));

      // Check Outbox
      final syncItems = await db.syncQueueDao.getPendingItems();
      // 1 from create, 1 from update = 2 items
      expect(syncItems.length, 2);
      expect(syncItems.last.entityId, created.id);
      expect(syncItems.last.operation, SyncOperation.upsert.toDbValue());
    });

    test('throws ExpenseNotFoundException when updating non-existent expense', () async {
      final updateInput = UpdateExpenseInput(
        id: 'non-existent-id',
        amountPaise: 5000,
        category: ExpenseCategory.other,
        expenseDate: DateTime.now(),
      );

      expect(
        () => repository.updateExpense(updateInput),
        throwsA(isA<ExpenseNotFoundException>()),
      );
    });

    test('deletes expense and atomically enqueues DELETE operation', () async {
      final created = await repository.createExpense(
        CreateExpenseInput(
          amountPaise: 50000,
          category: ExpenseCategory.shopping,
          expenseDate: DateTime.now(),
        ),
      );

      expect(await repository.getExpenseById(created.id), isNotNull);

      await repository.deleteExpense(created.id);

      expect(await repository.getExpenseById(created.id), isNull);

      final syncItems = await db.syncQueueDao.getPendingItems();
      expect(syncItems.length, 2); // 1 upsert from create, 1 delete from deleteExpense
      expect(syncItems.last.entityId, created.id);
      expect(syncItems.last.operation, SyncOperation.delete.toDbValue());
    });

    test('throws ExpenseNotFoundException when deleting non-existent expense', () async {
      expect(
        () => repository.deleteExpense('invalid-id'),
        throwsA(isA<ExpenseNotFoundException>()),
      );
    });

    test('watchExpenses and getExpenses return deterministic ordering', () async {
      final d1 = DateTime.utc(2026, 4, 10);
      final d2 = DateTime.utc(2026, 4, 12);
      final d3 = DateTime.utc(2026, 4, 11);

      await repository.createExpense(CreateExpenseInput(amountPaise: 1000, category: ExpenseCategory.food, expenseDate: d1));
      await repository.createExpense(CreateExpenseInput(amountPaise: 2000, category: ExpenseCategory.bills, expenseDate: d2));
      await repository.createExpense(CreateExpenseInput(amountPaise: 3000, category: ExpenseCategory.health, expenseDate: d3));

      final expenses = await repository.getExpenses();
      expect(expenses.length, 3);
      expect(expenses[0].amountPaise, 2000); // April 12
      expect(expenses[1].amountPaise, 3000); // April 11
      expect(expenses[2].amountPaise, 1000); // April 10

      final streamList = await repository.watchExpenses().first;
      expect(streamList.length, 3);
      expect(streamList[0].amountPaise, 2000);
    });

    test('getExpensesByDateRange and watchExpensesByDateRange filter with inclusive start / exclusive end', () async {
      final d1 = DateTime.utc(2026, 5, 1);
      final d2 = DateTime.utc(2026, 5, 5);
      final d3 = DateTime.utc(2026, 5, 10);

      await repository.createExpense(CreateExpenseInput(amountPaise: 1000, category: ExpenseCategory.food, expenseDate: d1));
      await repository.createExpense(CreateExpenseInput(amountPaise: 2000, category: ExpenseCategory.bills, expenseDate: d2));
      await repository.createExpense(CreateExpenseInput(amountPaise: 3000, category: ExpenseCategory.health, expenseDate: d3));

      // Range: [May 2, May 10) -> Only May 5 (d2)
      final filtered = await repository.getExpensesByDateRange(
        startDate: DateTime.utc(2026, 5, 2),
        endDate: DateTime.utc(2026, 5, 10),
      );

      expect(filtered.length, 1);
      expect(filtered.first.amountPaise, 2000);

      final streamFiltered = await repository.watchExpensesByDateRange(
        startDate: DateTime.utc(2026, 5, 1),
        endDate: DateTime.utc(2026, 5, 6),
      ).first;

      // Range: [May 1, May 6) -> May 5 and May 1
      expect(streamFiltered.length, 2);
      expect(streamFiltered[0].amountPaise, 2000);
      expect(streamFiltered[1].amountPaise, 1000);
    });

    test('expense isolation: does not touch merchant, purchase, or settlement tables', () async {
      await db.merchantDao.insertMerchant(
        const MerchantsCompanion(
          id: Value('m_test'),
          name: Value('Test Store'),
          category: Value('GROCERY'),
          upiVpa: Value('store@upi'),
          createdAt: Value(1000),
          updatedAt: Value(1000),
          isActive: Value(true),
        ),
      );

      await repository.createExpense(
        CreateExpenseInput(
          amountPaise: 75000,
          category: ExpenseCategory.shopping,
          expenseDate: DateTime.now(),
        ),
      );

      // Verify merchants and purchases are untouched
      final allMerchants = await db.merchantDao.getAllMerchants();
      expect(allMerchants.length, 1);
      expect(allMerchants.first.id, 'm_test');

      final totalOutstanding = await db.purchaseDao.getTotalOutstanding();
      expect(totalOutstanding, 0);

      final allPurchases = await db.purchaseDao.getUnsettledPurchases('m_test');
      expect(allPurchases.isEmpty, true);
    });
  });
}

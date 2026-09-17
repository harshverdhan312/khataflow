import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('ExpenseDao Tests', () {
    test('inserts and retrieves an expense by id', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.expenseDao.insertExpense(
        ExpensesCompanion(
          id: const Value('e1'),
          amountPaise: const Value(25000),
          category: const Value('FOOD'),
          note: const Value('Lunch'),
          expenseDate: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('PENDING'),
        ),
      );

      final fetched = await db.expenseDao.getExpenseById('e1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'e1');
      expect(fetched.amountPaise, 25000);
      expect(fetched.category, 'FOOD');
      expect(fetched.note, 'Lunch');
      expect(fetched.expenseDate, now);
      expect(fetched.createdAt, now);
      expect(fetched.syncStatus, 'PENDING');
    });

    test('getExpenseById returns null for non-existent id', () async {
      final fetched = await db.expenseDao.getExpenseById('non_existent');
      expect(fetched, isNull);
    });

    test('watchExpenses and getExpenses order by expenseDate DESC, createdAt DESC deterministically', () async {
      final base = 1700000000000;

      // Expense 1: Older date
      await db.expenseDao.insertExpense(
        ExpensesCompanion(
          id: const Value('e1'),
          amountPaise: const Value(10000),
          category: const Value('FOOD'),
          note: const Value('Old food'),
          expenseDate: Value(base),
          createdAt: Value(base),
          updatedAt: Value(base),
        ),
      );

      // Expense 2: Newer date, earlier createdAt
      await db.expenseDao.insertExpense(
        ExpensesCompanion(
          id: const Value('e2'),
          amountPaise: const Value(20000),
          category: const Value('TRANSPORT'),
          note: const Value('Cab'),
          expenseDate: Value(base + 10000),
          createdAt: Value(base + 1000),
          updatedAt: Value(base + 1000),
        ),
      );

      // Expense 3: Same expenseDate as Expense 2, but later createdAt
      await db.expenseDao.insertExpense(
        ExpensesCompanion(
          id: const Value('e3'),
          amountPaise: const Value(30000),
          category: const Value('SHOPPING'),
          note: const Value('Shirt'),
          expenseDate: Value(base + 10000),
          createdAt: Value(base + 2000),
          updatedAt: Value(base + 2000),
        ),
      );

      // Verify getExpenses() ordering
      final expenses = await db.expenseDao.getExpenses();
      expect(expenses.length, 3);
      expect(expenses[0].id, 'e3'); // newer date + later created
      expect(expenses[1].id, 'e2'); // newer date + earlier created
      expect(expenses[2].id, 'e1'); // older date

      // Verify watchExpenses() ordering
      final streamList = await db.expenseDao.watchExpenses().first;
      expect(streamList.length, 3);
      expect(streamList[0].id, 'e3');
      expect(streamList[1].id, 'e2');
      expect(streamList[2].id, 'e1');
    });

    test('getExpensesByDateRange and watchExpensesByDateRange filter with [start, end) semantics', () async {
      final t1 = 10000;
      final t2 = 20000;
      final t4 = 40000;

      // Before range
      await db.expenseDao.insertExpense(
        ExpensesCompanion(
          id: const Value('e_before'),
          amountPaise: const Value(5000),
          category: const Value('FOOD'),
          expenseDate: Value(t1),
          createdAt: Value(t1),
          updatedAt: Value(t1),
        ),
      );

      // Inside range (exact start boundary)
      await db.expenseDao.insertExpense(
        ExpensesCompanion(
          id: const Value('e_start'),
          amountPaise: const Value(6000),
          category: const Value('FOOD'),
          expenseDate: Value(t2),
          createdAt: Value(t2),
          updatedAt: Value(t2),
        ),
      );

      // Inside range (middle)
      await db.expenseDao.insertExpense(
        ExpensesCompanion(
          id: const Value('e_mid'),
          amountPaise: const Value(7000),
          category: const Value('FOOD'),
          expenseDate: Value(t2 + 5000),
          createdAt: Value(t2 + 5000),
          updatedAt: Value(t2 + 5000),
        ),
      );

      // On end boundary (exclusive -> should not be included)
      await db.expenseDao.insertExpense(
        ExpensesCompanion(
          id: const Value('e_end_bound'),
          amountPaise: const Value(8000),
          category: const Value('FOOD'),
          expenseDate: Value(t4),
          createdAt: Value(t4),
          updatedAt: Value(t4),
        ),
      );

      final ranged = await db.expenseDao.getExpensesByDateRange(t2, t4);
      expect(ranged.length, 2);
      expect(ranged.map((e) => e.id), containsAll(['e_start', 'e_mid']));
      expect(ranged.any((e) => e.id == 'e_before'), isFalse);
      expect(ranged.any((e) => e.id == 'e_end_bound'), isFalse);

      final streamRanged = await db.expenseDao.watchExpensesByDateRange(t2, t4).first;
      expect(streamRanged.length, 2);
    });

    test('updates an existing expense', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.expenseDao.insertExpense(
        ExpensesCompanion(
          id: const Value('e1'),
          amountPaise: const Value(25000),
          category: const Value('FOOD'),
          note: const Value('Lunch'),
          expenseDate: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final updated = await db.expenseDao.updateExpense(
        ExpensesCompanion(
          id: const Value('e1'),
          amountPaise: const Value(30000),
          category: const Value('FOOD'),
          note: const Value('Buffet Lunch'),
          expenseDate: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now + 1000),
        ),
      );

      expect(updated, isTrue);

      final fetched = await db.expenseDao.getExpenseById('e1');
      expect(fetched!.amountPaise, 30000);
      expect(fetched.note, 'Buffet Lunch');
      expect(fetched.updatedAt, now + 1000);
    });

    test('deletes an expense by id', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.expenseDao.insertExpense(
        ExpensesCompanion(
          id: const Value('e1'),
          amountPaise: const Value(25000),
          category: const Value('FOOD'),
          expenseDate: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final rowsDeleted = await db.expenseDao.deleteExpense('e1');
      expect(rowsDeleted, 1);

      final fetched = await db.expenseDao.getExpenseById('e1');
      expect(fetched, isNull);
    });
  });
}

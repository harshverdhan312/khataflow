import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  group('ExpenseCategory Enum Tests', () {
    test('toDbValue maps correctly for all categories', () {
      expect(ExpenseCategory.food.toDbValue(), 'FOOD');
      expect(ExpenseCategory.transport.toDbValue(), 'TRANSPORT');
      expect(ExpenseCategory.shopping.toDbValue(), 'SHOPPING');
      expect(ExpenseCategory.bills.toDbValue(), 'BILLS');
      expect(ExpenseCategory.entertainment.toDbValue(), 'ENTERTAINMENT');
      expect(ExpenseCategory.health.toDbValue(), 'HEALTH');
      expect(ExpenseCategory.education.toDbValue(), 'EDUCATION');
      expect(ExpenseCategory.other.toDbValue(), 'OTHER');
    });

    test('fromDbValue converts valid strings to enum', () {
      expect(ExpenseCategory.fromDbValue('FOOD'), ExpenseCategory.food);
      expect(ExpenseCategory.fromDbValue('transport'), ExpenseCategory.transport);
      expect(ExpenseCategory.fromDbValue('SHOPPING'), ExpenseCategory.shopping);
      expect(ExpenseCategory.fromDbValue('BILLS'), ExpenseCategory.bills);
      expect(ExpenseCategory.fromDbValue('ENTERTAINMENT'), ExpenseCategory.entertainment);
      expect(ExpenseCategory.fromDbValue('HEALTH'), ExpenseCategory.health);
      expect(ExpenseCategory.fromDbValue('EDUCATION'), ExpenseCategory.education);
      expect(ExpenseCategory.fromDbValue('OTHER'), ExpenseCategory.other);
    });

    test('fromDbValue falls back to other for unknown string', () {
      expect(ExpenseCategory.fromDbValue('UNKNOWN_CATEGORY'), ExpenseCategory.other);
      expect(ExpenseCategory.fromDbValue(''), ExpenseCategory.other);
    });

    test('tryFromDbValue returns null for unknown string', () {
      expect(ExpenseCategory.tryFromDbValue('FOOD'), ExpenseCategory.food);
      expect(ExpenseCategory.tryFromDbValue('UNKNOWN_CATEGORY'), isNull);
      expect(ExpenseCategory.tryFromDbValue(''), isNull);
    });

    test('displayName returns user-facing readable string', () {
      expect(ExpenseCategory.food.displayName, 'Food');
      expect(ExpenseCategory.transport.displayName, 'Transport');
      expect(ExpenseCategory.shopping.displayName, 'Shopping');
      expect(ExpenseCategory.bills.displayName, 'Bills');
      expect(ExpenseCategory.entertainment.displayName, 'Entertainment');
      expect(ExpenseCategory.health.displayName, 'Health');
      expect(ExpenseCategory.education.displayName, 'Education');
      expect(ExpenseCategory.other.displayName, 'Other');
    });
  });

  group('Expense Domain Entity Tests', () {
    test('constructs valid Expense with all fields', () {
      final now = DateTime.now();
      final expenseDate = now.subtract(const Duration(days: 1));

      final expense = Expense(
        id: 'e1',
        amountPaise: 25000,
        category: ExpenseCategory.food,
        note: 'Lunch at Cafe',
        expenseDate: expenseDate,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
      );

      expect(expense.id, 'e1');
      expect(expense.amountPaise, 25000);
      expect(expense.category, ExpenseCategory.food);
      expect(expense.note, 'Lunch at Cafe');
      expect(expense.expenseDate, expenseDate);
      expect(expense.createdAt, now);
      expect(expense.updatedAt, now);
      expect(expense.syncStatus, SyncStatus.pending);
    });

    test('copyWith updates specified fields only', () {
      final now = DateTime.now();
      final expense = Expense(
        id: 'e1',
        amountPaise: 25000,
        category: ExpenseCategory.food,
        note: 'Lunch',
        expenseDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final updated = expense.copyWith(
        amountPaise: 30000,
        note: 'Dinner',
      );

      expect(updated.id, 'e1');
      expect(updated.amountPaise, 30000);
      expect(updated.category, ExpenseCategory.food);
      expect(updated.note, 'Dinner');
      expect(updated.createdAt, now);
    });

    test('equality and hashCode match identical instances', () {
      final now = DateTime.now();
      final e1 = Expense(
        id: 'e1',
        amountPaise: 15000,
        category: ExpenseCategory.transport,
        expenseDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final e2 = Expense(
        id: 'e1',
        amountPaise: 15000,
        category: ExpenseCategory.transport,
        expenseDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final e3 = Expense(
        id: 'e2',
        amountPaise: 15000,
        category: ExpenseCategory.transport,
        expenseDate: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2.hashCode));
      expect(e1, isNot(equals(e3)));
    });

    test('input models preserve integer paise and fields', () {
      final now = DateTime.now();
      final createInput = CreateExpenseInput(
        amountPaise: 9950,
        category: ExpenseCategory.shopping,
        note: 'Book',
        expenseDate: now,
      );

      expect(createInput.amountPaise, 9950);
      expect(createInput.category, ExpenseCategory.shopping);
      expect(createInput.note, 'Book');
      expect(createInput.expenseDate, now);

      final updateInput = UpdateExpenseInput(
        id: 'e1',
        amountPaise: 12000,
        category: ExpenseCategory.shopping,
        note: 'Books',
        expenseDate: now,
      );

      expect(updateInput.id, 'e1');
      expect(updateInput.amountPaise, 12000);
      expect(updateInput.category, ExpenseCategory.shopping);
      expect(updateInput.note, 'Books');
      expect(updateInput.expenseDate, now);
    });
  });
}

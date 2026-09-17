import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/expenses_table.dart';

part 'expense_dao.g.dart';

@DriftAccessor(tables: [Expenses])
class ExpenseDao extends DatabaseAccessor<AppDatabase> with _$ExpenseDaoMixin {
  ExpenseDao(super.db);

  /// Inserts a new expense into the database.
  Future<int> insertExpense(ExpensesCompanion companion) {
    return into(expenses).insert(companion);
  }

  /// Retrieves an expense by its unique UUID [id].
  Future<ExpenseEntity?> getExpenseById(String id) {
    return (select(expenses)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Watches all expenses ordered deterministically by [expenseDate DESC, createdAt DESC].
  Stream<List<ExpenseEntity>> watchExpenses() {
    return (select(expenses)
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.expenseDate),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch();
  }

  /// Retrieves all expenses ordered deterministically by [expenseDate DESC, createdAt DESC].
  Future<List<ExpenseEntity>> getExpenses() {
    return (select(expenses)
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.expenseDate),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .get();
  }

  /// Watches expenses within the timestamp range [startMs, endMs) ordered by [expenseDate DESC, createdAt DESC].
  Stream<List<ExpenseEntity>> watchExpensesByDateRange(int startMs, int endMs) {
    return (select(expenses)
          ..where((tbl) => tbl.expenseDate.isBiggerOrEqualValue(startMs) & tbl.expenseDate.isSmallerThanValue(endMs))
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.expenseDate),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch();
  }

  /// Retrieves expenses within the timestamp range [startMs, endMs) ordered by [expenseDate DESC, createdAt DESC].
  Future<List<ExpenseEntity>> getExpensesByDateRange(int startMs, int endMs) {
    return (select(expenses)
          ..where((tbl) => tbl.expenseDate.isBiggerOrEqualValue(startMs) & tbl.expenseDate.isSmallerThanValue(endMs))
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.expenseDate),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .get();
  }

  /// Updates an existing expense entity.
  Future<bool> updateExpense(ExpensesCompanion companion) {
    return update(expenses).replace(companion);
  }

  /// Deletes an expense by its unique UUID [id].
  Future<int> deleteExpense(String id) {
    return (delete(expenses)..where((tbl) => tbl.id.equals(id))).go();
  }
}

import 'expense.dart';

abstract class ExpenseRepository {
  /// Creates a new expense entity and persists it atomically with outbox sync records.
  Future<Expense> createExpense(CreateExpenseInput input);

  /// Retrieves an expense by its unique UUID [id].
  Future<Expense?> getExpenseById(String id);

  /// Watches all expenses ordered by [expenseDate DESC, createdAt DESC].
  Stream<List<Expense>> watchExpenses();

  /// Retrieves all expenses ordered by [expenseDate DESC, createdAt DESC].
  Future<List<Expense>> getExpenses();

  /// Watches expenses within the inclusive/exclusive timestamp range [startDate, endDate) ordered by [expenseDate DESC, createdAt DESC].
  Stream<List<Expense>> watchExpensesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Retrieves expenses within the inclusive/exclusive timestamp range [startDate, endDate) ordered by [expenseDate DESC, createdAt DESC].
  Future<List<Expense>> getExpensesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Updates an existing expense entity and records an outbox sync record.
  Future<Expense> updateExpense(UpdateExpenseInput input);

  /// Deletes an expense by its unique UUID [id] and records an outbox sync record.
  Future<void> deleteExpense(String id);
}

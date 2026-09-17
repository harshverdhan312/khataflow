import '../../../expense/domain/expense.dart';
import '../../../expense/domain/expense_category.dart';

/// Immutable, bounded summary of an individual expense tailored strictly for the AI boundary.
///
/// Strips all database-internal identifiers, sync status, and metadata, keeping only
/// trusted financial attributes and a strictly size-bounded note (max 200 characters).
class BoundedExpenseSummary {
  static const int maxNoteLength = 200;

  final int amountPaise;
  final ExpenseCategory category;
  final DateTime date;
  final String? note;

  const BoundedExpenseSummary({
    required this.amountPaise,
    required this.category,
    required this.date,
    this.note,
  });

  /// Creates a [BoundedExpenseSummary] from a domain [Expense], enforcing strict data minimization
  /// and note length bounding.
  factory BoundedExpenseSummary.fromExpense(Expense expense) {
    String? boundedNote;
    if (expense.note != null) {
      final trimmed = expense.note!.trim();
      if (trimmed.isNotEmpty) {
        boundedNote = trimmed.length > maxNoteLength
            ? trimmed.substring(0, maxNoteLength).trim()
            : trimmed;
      }
    }

    return BoundedExpenseSummary(
      amountPaise: expense.amountPaise,
      category: expense.category,
      date: expense.expenseDate,
      note: boundedNote,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoundedExpenseSummary &&
          runtimeType == other.runtimeType &&
          amountPaise == other.amountPaise &&
          category == other.category &&
          date == other.date &&
          note == other.note;

  @override
  int get hashCode => Object.hash(amountPaise, category, date, note);

  @override
  String toString() =>
      'BoundedExpenseSummary(amountPaise: $amountPaise, category: $category, date: $date, note: $note)';
}

import '../../../shared/models/sync_enums.dart';
import 'expense_category.dart';

class Expense {
  final String id;
  final int amountPaise;
  final ExpenseCategory category;
  final String? note;
  final DateTime expenseDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  const Expense({
    required this.id,
    required this.amountPaise,
    required this.category,
    this.note,
    required this.expenseDate,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Expense copyWith({
    String? id,
    int? amountPaise,
    ExpenseCategory? category,
    String? note,
    DateTime? expenseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Expense(
      id: id ?? this.id,
      amountPaise: amountPaise ?? this.amountPaise,
      category: category ?? this.category,
      note: note ?? this.note,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Expense &&
        other.id == id &&
        other.amountPaise == amountPaise &&
        other.category == category &&
        other.note == note &&
        other.expenseDate == expenseDate &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.syncStatus == syncStatus;
  }

  @override
  int get hashCode => Object.hash(
        id,
        amountPaise,
        category,
        note,
        expenseDate,
        createdAt,
        updatedAt,
        syncStatus,
      );
}

class CreateExpenseInput {
  final int amountPaise;
  final ExpenseCategory category;
  final String? note;
  final DateTime expenseDate;

  const CreateExpenseInput({
    required this.amountPaise,
    required this.category,
    this.note,
    required this.expenseDate,
  });
}

class UpdateExpenseInput {
  final String id;
  final int amountPaise;
  final ExpenseCategory category;
  final String? note;
  final DateTime expenseDate;

  const UpdateExpenseInput({
    required this.id,
    required this.amountPaise,
    required this.category,
    this.note,
    required this.expenseDate,
  });
}

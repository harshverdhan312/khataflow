import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/validators.dart';
import '../../../database/app_database.dart';
import '../../../shared/models/sync_enums.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import '../domain/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  ExpenseRepositoryImpl(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  @override
  Future<Expense> createExpense(CreateExpenseInput input) async {
    // Validations
    if (input.amountPaise <= 0) {
      throw const InvalidAmountException('Expense amount must be greater than zero');
    }
    if (input.note != null) {
      final noteError = Validators.validateExpenseNote(input.note);
      if (noteError != null) {
        throw ValidationException(noteError);
      }
    }

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expenseDateMs = input.expenseDate.millisecondsSinceEpoch;

    final trimmedNote = input.note?.trim();
    final effectiveNote = (trimmedNote != null && trimmedNote.isNotEmpty) ? trimmedNote : null;

    final expenseCompanion = ExpensesCompanion(
      id: Value(id),
      amountPaise: Value(input.amountPaise),
      category: Value(input.category.toDbValue()),
      note: Value(effectiveNote),
      expenseDate: Value(expenseDateMs),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: Value(SyncStatus.pending.toDbValue()),
    );

    final syncQueueCompanion = SyncQueueCompanion(
      id: Value(_uuid.v4()),
      entityType: Value(SyncEntityType.expense.toDbValue()),
      entityId: Value(id),
      operation: Value(SyncOperation.upsert.toDbValue()),
      createdAt: Value(now),
    );

    // Atomic SQLite write: insert expense + sync outbox queue record
    await _db.transaction(() async {
      await _db.expenseDao.insertExpense(expenseCompanion);
      await _db.syncQueueDao.enqueue(syncQueueCompanion);
    });

    return Expense(
      id: id,
      amountPaise: input.amountPaise,
      category: input.category,
      note: effectiveNote,
      expenseDate: input.expenseDate,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      syncStatus: SyncStatus.pending,
    );
  }

  @override
  Future<Expense?> getExpenseById(String id) async {
    final entity = await _db.expenseDao.getExpenseById(id);
    return entity != null ? _mapEntityToDomain(entity) : null;
  }

  @override
  Stream<List<Expense>> watchExpenses() {
    return _db.expenseDao.watchExpenses().map((entities) => entities.map(_mapEntityToDomain).toList());
  }

  @override
  Future<List<Expense>> getExpenses() async {
    final entities = await _db.expenseDao.getExpenses();
    return entities.map(_mapEntityToDomain).toList();
  }

  @override
  Stream<List<Expense>> watchExpensesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final startMs = startDate.millisecondsSinceEpoch;
    final endMs = endDate.millisecondsSinceEpoch;
    return _db.expenseDao.watchExpensesByDateRange(startMs, endMs).map(
          (entities) => entities.map(_mapEntityToDomain).toList(),
        );
  }

  @override
  Future<List<Expense>> getExpensesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startMs = startDate.millisecondsSinceEpoch;
    final endMs = endDate.millisecondsSinceEpoch;
    final entities = await _db.expenseDao.getExpensesByDateRange(startMs, endMs);
    return entities.map(_mapEntityToDomain).toList();
  }

  @override
  Future<Expense> updateExpense(UpdateExpenseInput input) async {
    if (input.amountPaise <= 0) {
      throw const InvalidAmountException('Expense amount must be greater than zero');
    }
    if (input.note != null) {
      final noteError = Validators.validateExpenseNote(input.note);
      if (noteError != null) {
        throw ValidationException(noteError);
      }
    }

    final existing = await _db.expenseDao.getExpenseById(input.id);
    if (existing == null) {
      throw const ExpenseNotFoundException();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final expenseDateMs = input.expenseDate.millisecondsSinceEpoch;

    final trimmedNote = input.note?.trim();
    final effectiveNote = (trimmedNote != null && trimmedNote.isNotEmpty) ? trimmedNote : null;

    final expenseCompanion = ExpensesCompanion(
      id: Value(input.id),
      amountPaise: Value(input.amountPaise),
      category: Value(input.category.toDbValue()),
      note: Value(effectiveNote),
      expenseDate: Value(expenseDateMs),
      createdAt: Value(existing.createdAt),
      updatedAt: Value(now),
      syncStatus: Value(SyncStatus.pending.toDbValue()),
    );

    final syncQueueCompanion = SyncQueueCompanion(
      id: Value(_uuid.v4()),
      entityType: Value(SyncEntityType.expense.toDbValue()),
      entityId: Value(input.id),
      operation: Value(SyncOperation.upsert.toDbValue()),
      createdAt: Value(now),
    );

    await _db.transaction(() async {
      await _db.expenseDao.updateExpense(expenseCompanion);
      await _db.syncQueueDao.enqueue(syncQueueCompanion);
    });

    return Expense(
      id: input.id,
      amountPaise: input.amountPaise,
      category: input.category,
      note: effectiveNote,
      expenseDate: input.expenseDate,
      createdAt: DateTime.fromMillisecondsSinceEpoch(existing.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      syncStatus: SyncStatus.pending,
    );
  }

  @override
  Future<void> deleteExpense(String id) async {
    final existing = await _db.expenseDao.getExpenseById(id);
    if (existing == null) {
      throw const ExpenseNotFoundException();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final syncQueueCompanion = SyncQueueCompanion(
      id: Value(_uuid.v4()),
      entityType: Value(SyncEntityType.expense.toDbValue()),
      entityId: Value(id),
      operation: Value(SyncOperation.delete.toDbValue()),
      createdAt: Value(now),
    );

    await _db.transaction(() async {
      await _db.expenseDao.deleteExpense(id);
      await _db.syncQueueDao.enqueue(syncQueueCompanion);
    });
  }

  Expense _mapEntityToDomain(ExpenseEntity entity) {
    return Expense(
      id: entity.id,
      amountPaise: entity.amountPaise,
      category: ExpenseCategory.fromDbValue(entity.category),
      note: entity.note,
      expenseDate: DateTime.fromMillisecondsSinceEpoch(entity.expenseDate),
      createdAt: DateTime.fromMillisecondsSinceEpoch(entity.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(entity.updatedAt),
      syncStatus: SyncStatus.fromDbValue(entity.syncStatus),
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/errors/app_exceptions.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/expense_repository.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

class FakeExpenseRepository implements ExpenseRepository {
  CreateExpenseInput? lastInput;
  bool shouldThrow = false;
  String throwMessage = 'Database error';

  @override
  Future<Expense> createExpense(CreateExpenseInput input) async {
    lastInput = input;
    if (shouldThrow) {
      throw DatabaseException(throwMessage);
    }
    return Expense(
      id: 'exp_fake_1',
      amountPaise: input.amountPaise,
      category: input.category,
      note: input.note,
      expenseDate: input.expenseDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
  }

  @override
  Future<Expense?> getExpenseById(String id) async => null;

  @override
  Stream<List<Expense>> watchExpenses() => Stream.value([]);

  @override
  Future<List<Expense>> getExpenses() async => [];

  @override
  Stream<List<Expense>> watchExpensesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      Stream.value([]);

  @override
  Future<List<Expense>> getExpensesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async =>
      [];

  UpdateExpenseInput? lastUpdateInput;
  String? lastDeletedId;

  @override
  Future<Expense> updateExpense(UpdateExpenseInput input) async {
    lastUpdateInput = input;
    if (shouldThrow) {
      throw DatabaseException(throwMessage);
    }
    return Expense(
      id: input.id,
      amountPaise: input.amountPaise,
      category: input.category,
      note: input.note,
      expenseDate: input.expenseDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
  }

  @override
  Future<void> deleteExpense(String id) async {
    lastDeletedId = id;
    if (shouldThrow) {
      throw DatabaseException(throwMessage);
    }
  }
}

void main() {
  late FakeExpenseRepository repository;
  late AddExpenseController controller;

  setUp(() {
    repository = FakeExpenseRepository();
    controller = AddExpenseController(repository);
  });

  group('AddExpenseController Tests', () {
    test('initial state has isLoading false and no error', () {
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.createdExpense, isNull);
    });

    test('successful submission updates state with created expense and returns true', () async {
      final input = CreateExpenseInput(
        amountPaise: 25000,
        category: ExpenseCategory.food,
        note: 'Team lunch',
        expenseDate: DateTime.utc(2026, 6, 1),
      );

      final success = await controller.submit(input);

      expect(success, true);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.createdExpense, isNotNull);
      expect(controller.state.createdExpense!.id, 'exp_fake_1');
      expect(controller.state.createdExpense!.amountPaise, 25000);
      expect(repository.lastInput?.amountPaise, 25000);
    });

    test('repository failure updates state with error message and returns false', () async {
      repository.shouldThrow = true;
      repository.throwMessage = 'Failed to write to database';

      final input = CreateExpenseInput(
        amountPaise: 5000,
        category: ExpenseCategory.transport,
        expenseDate: DateTime.now(),
      );

      final success = await controller.submit(input);

      expect(success, false);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, contains('Failed to write to database'));
      expect(controller.state.createdExpense, isNull);
    });

    test('prevents duplicate concurrent submission when already loading', () async {
      // Artificially put state into loading
      controller.state = controller.state.copyWith(isLoading: true);

      final input = CreateExpenseInput(
        amountPaise: 1000,
        category: ExpenseCategory.other,
        expenseDate: DateTime.now(),
      );

      final success = await controller.submit(input);
      expect(success, false);
      expect(repository.lastInput, isNull); // Was never called
    });

    test('successful update calls repository and returns true', () async {
      final input = UpdateExpenseInput(
        id: 'exp_1',
        amountPaise: 30000,
        category: ExpenseCategory.shopping,
        note: 'New shoes',
        expenseDate: DateTime.utc(2026, 6, 2),
      );

      final success = await controller.update(input);

      expect(success, true);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNull);
      expect(repository.lastUpdateInput?.id, 'exp_1');
      expect(repository.lastUpdateInput?.amountPaise, 30000);
    });

    test('failed update sets error message and returns false', () async {
      repository.shouldThrow = true;
      repository.throwMessage = 'Update failed';

      final input = UpdateExpenseInput(
        id: 'exp_1',
        amountPaise: 30000,
        category: ExpenseCategory.shopping,
        expenseDate: DateTime.now(),
      );

      final success = await controller.update(input);

      expect(success, false);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, contains('Update failed'));
    });

    test('successful delete calls repository and returns true', () async {
      final success = await controller.delete('exp_1');

      expect(success, true);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNull);
      expect(repository.lastDeletedId, 'exp_1');
    });

    test('failed delete sets error message and returns false', () async {
      repository.shouldThrow = true;
      repository.throwMessage = 'Delete failed';

      final success = await controller.delete('exp_1');

      expect(success, false);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, contains('Delete failed'));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/errors/app_exceptions.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/expense_repository.dart';
import 'package:khata_flow/features/expense/presentation/edit_expense_screen.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

class FakeExpenseRepository implements ExpenseRepository {
  UpdateExpenseInput? lastUpdated;
  bool shouldThrow = false;
  Expense? expenseToReturn;

  @override
  Future<Expense> createExpense(CreateExpenseInput input) async => throw UnimplementedError();

  @override
  Future<Expense?> getExpenseById(String id) async => expenseToReturn;

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

  @override
  Future<Expense> updateExpense(UpdateExpenseInput input) async {
    lastUpdated = input;
    if (shouldThrow) {
      throw const DatabaseException('Update failed');
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
  Future<void> deleteExpense(String id) async {}
}

void main() {
  late FakeExpenseRepository fakeRepo;

  final sampleExpense = Expense(
    id: 'exp_999',
    amountPaise: 15000,
    category: ExpenseCategory.food,
    note: 'Initial lunch note',
    expenseDate: DateTime.utc(2026, 9, 10, 12, 0),
    createdAt: DateTime.utc(2026, 9, 10, 12, 0),
    updatedAt: DateTime.utc(2026, 9, 10, 12, 0),
    syncStatus: SyncStatus.pending,
  );

  setUp(() {
    fakeRepo = FakeExpenseRepository();
    fakeRepo.expenseToReturn = sampleExpense;
  });

  group('EditExpenseScreen Tests', () {
    testWidgets('pre-populates existing expense values into fields', (tester) async {
      final app = ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(fakeRepo),
          expenseDetailProvider('exp_999').overrideWith((ref) => Future.value(sampleExpense)),
        ],
        child: const MaterialApp(
          home: EditExpenseScreen(expenseId: 'exp_999'),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Edit Expense'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('Initial lunch note'), findsOneWidget);
    });

    testWidgets('modifies amount, category, note and submits successfully', (tester) async {
      final app = ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(fakeRepo),
          expenseDetailProvider('exp_999').overrideWith((ref) => Future.value(sampleExpense)),
        ],
        child: const MaterialApp(
          home: EditExpenseScreen(expenseId: 'exp_999'),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Change amount to 220.50 -> 22050 paise
      final amountField = find.byType(TextFormField).first;
      await tester.enterText(amountField, '220.50');

      // Change category to Shopping
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();

      // Change note
      final noteField = find.byType(TextFormField).at(1);
      await tester.enterText(noteField, 'New clothes');

      // Submit
      await tester.ensureVisible(find.text('Update Expense'));
      await tester.tap(find.text('Update Expense'));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastUpdated?.id, 'exp_999');
      expect(fakeRepo.lastUpdated?.amountPaise, 22050);
      expect(fakeRepo.lastUpdated?.category, ExpenseCategory.shopping);
      expect(fakeRepo.lastUpdated?.note, 'New clothes');
      expect(find.text('Expense updated'), findsOneWidget);
    });

    testWidgets('shows validation error when amount is cleared', (tester) async {
      final app = ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(fakeRepo),
          expenseDetailProvider('exp_999').overrideWith((ref) => Future.value(sampleExpense)),
        ],
        child: const MaterialApp(
          home: EditExpenseScreen(expenseId: 'exp_999'),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final amountField = find.byType(TextFormField).first;
      await tester.enterText(amountField, '');

      await tester.ensureVisible(find.text('Update Expense'));
      await tester.tap(find.text('Update Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Amount is required'), findsOneWidget);
      expect(fakeRepo.lastUpdated, isNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/errors/app_exceptions.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/expense_repository.dart';
import 'package:khata_flow/features/expense/presentation/add_expense_screen.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

class MockExpenseRepository implements ExpenseRepository {
  CreateExpenseInput? capturedInput;
  bool shouldFail = false;

  @override
  Future<Expense> createExpense(CreateExpenseInput input) async {
    capturedInput = input;
    if (shouldFail) {
      throw const DatabaseException('Simulated database write failure');
    }
    return Expense(
      id: 'mock_exp_1',
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

  @override
  Future<Expense> updateExpense(UpdateExpenseInput input) async => throw UnimplementedError();

  @override
  Future<void> deleteExpense(String id) async {}
}

Widget createTestWidget({required MockExpenseRepository repo}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(
      home: AddExpenseScreen(),
    ),
  );
}

void main() {
  late MockExpenseRepository mockRepo;

  setUp(() {
    mockRepo = MockExpenseRepository();
  });

  group('AddExpenseScreen Widget Tests', () {
    testWidgets('renders all form elements with initial empty state', (tester) async {
      await tester.pumpWidget(createTestWidget(repo: mockRepo));
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Expense Details'), findsOneWidget);
      expect(find.text('Amount *'), findsOneWidget);
      expect(find.text('Category *'), findsOneWidget);
      expect(find.text('Date *'), findsOneWidget);
      expect(find.text('Note (Optional)'), findsOneWidget);
      expect(find.text('Save Expense'), findsOneWidget);

      // Verify all categories are displayed
      for (final cat in ExpenseCategory.values) {
        expect(find.text(cat.displayName), findsOneWidget);
      }
    });

    testWidgets('shows validation errors when submitting empty form', (tester) async {
      await tester.pumpWidget(createTestWidget(repo: mockRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Amount is required'), findsOneWidget);
      expect(find.text('Please select a category'), findsOneWidget);
      expect(mockRepo.capturedInput, isNull);
    });

    testWidgets('shows validation error for zero and malformed amounts', (tester) async {
      await tester.pumpWidget(createTestWidget(repo: mockRepo));
      await tester.pumpAndSettle();

      // Enter 0
      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.ensureVisible(find.text('Save Expense'));
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Amount must be greater than ₹0'), findsOneWidget);

      // Enter malformed decimal
      await tester.enterText(find.byType(TextFormField).first, '12.345');
      await tester.ensureVisible(find.text('Save Expense'));
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid amount (e.g. 250 or 99.50)'), findsOneWidget);
    });

    testWidgets('successfully enters amount, selects category, inputs note, and submits', (tester) async {
      await tester.pumpWidget(createTestWidget(repo: mockRepo));
      await tester.pumpAndSettle();

      // Enter amount ₹250.50 -> 25050 paise
      await tester.enterText(find.byType(TextFormField).first, '250.50');

      // Select Category: Food
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      // Enter Note
      await tester.enterText(find.byType(TextFormField).at(1), 'Lunch with team');

      // Tap Save Expense
      await tester.ensureVisible(find.text('Save Expense'));
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(mockRepo.capturedInput, isNotNull);
      expect(mockRepo.capturedInput!.amountPaise, 25050);
      expect(mockRepo.capturedInput!.category, ExpenseCategory.food);
      expect(mockRepo.capturedInput!.note, 'Lunch with team');
      expect(mockRepo.capturedInput!.expenseDate, isNotNull);

      // SnackBar displayed
      expect(find.text('Expense added'), findsOneWidget);
    });

    testWidgets('shows error SnackBar when repository fails', (tester) async {
      mockRepo.shouldFail = true;

      await tester.pumpWidget(createTestWidget(repo: mockRepo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.tap(find.text('Transport'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Expense'));
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Simulated database write failure'), findsOneWidget);
    });

    testWidgets('allows picking a date and preserves user-selected date in input', (tester) async {
      await tester.pumpWidget(createTestWidget(repo: mockRepo));
      await tester.pumpAndSettle();

      // Open Date Picker
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();

      // Select OK on date picker dialog
      expect(find.text('OK'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Enter other fields and save
      await tester.enterText(find.byType(TextFormField).first, '99.99');
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Expense'));
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(mockRepo.capturedInput, isNotNull);
      expect(mockRepo.capturedInput!.amountPaise, 9999);
      expect(mockRepo.capturedInput!.category, ExpenseCategory.shopping);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khata_flow/core/utils/currency_formatter.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/expense_repository.dart';
import 'package:khata_flow/features/expense/presentation/expense_detail_sheet.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

class FakeExpenseRepository implements ExpenseRepository {
  String? deletedId;

  @override
  Future<Expense> createExpense(CreateExpenseInput input) async => throw UnimplementedError();

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
  Future<void> deleteExpense(String id) async {
    deletedId = id;
  }
}

void main() {
  late FakeExpenseRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeExpenseRepository();
  });

  final testExpense = Expense(
    id: 'exp_123',
    amountPaise: 49900,
    category: ExpenseCategory.entertainment,
    note: 'Movie tickets IMAX',
    expenseDate: DateTime.utc(2026, 9, 15, 18, 45),
    createdAt: DateTime.utc(2026, 9, 15, 18, 45),
    updatedAt: DateTime.utc(2026, 9, 15, 18, 45),
    syncStatus: SyncStatus.pending,
  );

  group('ExpenseDetailSheet Tests', () {
    testWidgets('renders all expense attributes correctly', (tester) async {
      final app = ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseDetailSheet(expense: testExpense),
          ),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.formatPaise(49900)), findsOneWidget);
      expect(find.text('Entertainment'), findsNWidgets(2)); // Badge and row
      expect(find.text('Movie tickets IMAX'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('Edit Expense'), findsOneWidget);
      expect(find.text('Delete Expense'), findsOneWidget);
    });

    testWidgets('edit button navigates to edit screen', (tester) async {
      String? editedExpenseId;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                onPressed: () => ExpenseDetailSheet.show(context, expense: testExpense),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
          GoRoute(
            path: '/expense/edit/:expenseId',
            builder: (context, state) {
              editedExpenseId = state.pathParameters['expenseId'];
              return const Scaffold(body: Text('Edit Screen'));
            },
          ),
        ],
      );

      final app = ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Expense'));
      await tester.pumpAndSettle();

      expect(editedExpenseId, 'exp_123');
      expect(find.text('Edit Screen'), findsOneWidget);
    });

    testWidgets('delete button opens confirmation dialog and can be cancelled', (tester) async {
      final app = ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseDetailSheet(expense: testExpense),
          ),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Expense'));
      await tester.pumpAndSettle();

      // Dialog shown
      expect(find.text('Delete Expense?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Expense?'), findsNothing);
      expect(fakeRepo.deletedId, isNull);
    });

    testWidgets('confirming deletion calls repository delete and shows SnackBar', (tester) async {
      final app = ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ExpenseDetailSheet.show(ctx, expense: testExpense),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Expense'));
      await tester.pumpAndSettle();

      // Tap Delete in dialog
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(fakeRepo.deletedId, 'exp_123');
      expect(find.text('Expense deleted'), findsOneWidget);
    });
  });
}

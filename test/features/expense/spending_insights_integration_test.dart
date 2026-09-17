import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/database/database_provider.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/expense/presentation/providers/spending_insights_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Spending Insights Reactive SQLite Integration Tests', () {
    test('Create -> Edit -> Delete Expenses reactively updates SpendingInsights', () async {
      final repo = container.read(expenseRepositoryProvider);
      final now = DateTime.now();
      final currentMonthDate = DateTime(now.year, now.month, 5);

      // 1. Initial State: 0 expenses
      await container.read(expensesStreamProvider.future);
      final initialInsights = container.read(spendingInsightsProvider).valueOrNull!;
      expect(initialInsights.isEmpty, isTrue);

      // 2. Create 2 expenses: Food ₹8,000, Transport ₹2,000 -> Food > 50% Concentration (High Priority)
      final exp1 = await repo.createExpense(
        CreateExpenseInput(
          amountPaise: 800000,
          category: ExpenseCategory.food,
          expenseDate: currentMonthDate,
          note: 'Groceries',
        ),
      );
      final exp2 = await repo.createExpense(
        CreateExpenseInput(
          amountPaise: 200000,
          category: ExpenseCategory.transport,
          expenseDate: currentMonthDate,
          note: 'Cab',
        ),
      );

      // Wait for stream emission
      await Future.delayed(const Duration(milliseconds: 50));
      final afterCreateInsights = container.read(spendingInsightsProvider).valueOrNull!;

      expect(afterCreateInsights.hasInsights, isTrue);
      expect(afterCreateInsights.highestPriority?.type, InsightType.spendingConcentration);
      expect(afterCreateInsights.highestPriority?.category, ExpenseCategory.food);

      // 3. Edit exp1: change Food to ₹2,000 (now Food = 2000, Transport = 2000 -> 50% each, no concentration)
      await repo.updateExpense(
        UpdateExpenseInput(
          id: exp1.id,
          amountPaise: 200000,
          category: ExpenseCategory.food,
          expenseDate: currentMonthDate,
          note: 'Light grocery',
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      final afterEditInsights = container.read(spendingInsightsProvider).valueOrNull!;
      expect(
        afterEditInsights.insights.any((i) => i.type == InsightType.spendingConcentration),
        isFalse,
      );

      // 4. Delete exp1 and exp2 -> 0 expenses -> empty insights
      await repo.deleteExpense(exp1.id);
      await repo.deleteExpense(exp2.id);

      await Future.delayed(const Duration(milliseconds: 50));
      final afterDeleteInsights = container.read(spendingInsightsProvider).valueOrNull!;
      expect(afterDeleteInsights.isEmpty, isTrue);
    });
  });
}

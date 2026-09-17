import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/spending_analytics_calculator.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  final referenceNow = DateTime(2026, 9, 17, 14, 30);

  Expense createTestExpense({
    required String id,
    required int amountPaise,
    required ExpenseCategory category,
    required DateTime expenseDate,
    DateTime? createdAt,
    String? note,
  }) {
    return Expense(
      id: id,
      amountPaise: amountPaise,
      category: category,
      note: note,
      expenseDate: expenseDate,
      createdAt: createdAt ?? expenseDate,
      updatedAt: createdAt ?? expenseDate,
      syncStatus: SyncStatus.synced,
    );
  }

  group('SpendingAnalyticsCalculator Tests', () {
    test('Empty data yields correct zero and null values', () {
      final analytics = deriveSpendingAnalytics([], now: referenceNow);

      expect(analytics.currentPeriodStart, DateTime(2026, 9, 1));
      expect(analytics.currentPeriodEnd, DateTime(2026, 10, 1));
      expect(analytics.previousPeriodStart, DateTime(2026, 8, 1));
      expect(analytics.previousPeriodEnd, DateTime(2026, 9, 1));

      expect(analytics.currentMonthTotalPaise, 0);
      expect(analytics.previousMonthTotalPaise, 0);
      expect(analytics.monthOverMonthChangePaise, 0);
      expect(analytics.monthOverMonthChangePercent, isNull);
      expect(analytics.currentMonthExpenseCount, 0);
      expect(analytics.previousMonthExpenseCount, 0);
      expect(analytics.hasCurrentMonthExpenses, isFalse);
      expect(analytics.hasPreviousMonthExpenses, isFalse);

      expect(analytics.categoryTotals, isEmpty);
      expect(analytics.topCategory, isNull);
      expect(analytics.largestExpense, isNull);
      expect(analytics.averageExpensePaise, isNull);
      expect(analytics.recentExpenses, isEmpty);
    });

    test('Current month aggregation sums integer paise and groups categories', () {
      final expenses = [
        createTestExpense(
          id: 'exp-1',
          amountPaise: 25000, // ₹250
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 2),
        ),
        createTestExpense(
          id: 'exp-2',
          amountPaise: 12000, // ₹120
          category: ExpenseCategory.transport,
          expenseDate: DateTime(2026, 9, 5),
        ),
        createTestExpense(
          id: 'exp-3',
          amountPaise: 150000, // ₹1500
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 10),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);

      expect(analytics.currentMonthTotalPaise, 187000); // ₹1870
      expect(analytics.currentMonthExpenseCount, 3);
      expect(analytics.hasCurrentMonthExpenses, isTrue);
      expect(analytics.previousMonthTotalPaise, 0);
      expect(analytics.previousMonthExpenseCount, 0);
      expect(analytics.hasPreviousMonthExpenses, isFalse);
      expect(analytics.monthOverMonthChangePaise, 187000);
      expect(analytics.monthOverMonthChangePercent, isNull); // Previous is 0

      expect(analytics.topCategory, ExpenseCategory.food);
      expect(analytics.categoryTotals.length, 2);
      expect(analytics.categoryTotals[0], const CategorySpending(
        category: ExpenseCategory.food,
        totalAmountPaise: 175000,
      ));
      expect(analytics.categoryTotals[1], const CategorySpending(
        category: ExpenseCategory.transport,
        totalAmountPaise: 12000,
      ));

      expect(analytics.largestExpense?.id, 'exp-3');
      expect(analytics.largestExpense?.amountPaise, 150000);

      // Average: 187000 / 3 = 62333.33 -> 62333 paise
      // Integer formula: (187000 + 3~/2) ~/ 3 = (187000 + 1) ~/ 3 = 62333
      expect(analytics.averageExpensePaise, 62333);
    });

    test('Previous month separation and positive MoM change percent', () {
      final expenses = [
        // Current month: ₹12,500 = 1,250,000 paise
        createTestExpense(
          id: 'curr-1',
          amountPaise: 1250000,
          category: ExpenseCategory.shopping,
          expenseDate: DateTime(2026, 9, 10),
        ),
        // Previous month: ₹10,000 = 1,000,000 paise
        createTestExpense(
          id: 'prev-1',
          amountPaise: 600000,
          category: ExpenseCategory.bills,
          expenseDate: DateTime(2026, 8, 12),
        ),
        createTestExpense(
          id: 'prev-2',
          amountPaise: 400000,
          category: ExpenseCategory.entertainment,
          expenseDate: DateTime(2026, 8, 25),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);

      expect(analytics.currentMonthTotalPaise, 1250000);
      expect(analytics.currentMonthExpenseCount, 1);
      expect(analytics.previousMonthTotalPaise, 1000000);
      expect(analytics.previousMonthExpenseCount, 2);
      expect(analytics.hasPreviousMonthExpenses, isTrue);

      expect(analytics.monthOverMonthChangePaise, 250000); // +₹2,500
      expect(analytics.monthOverMonthChangePercent, closeTo(25.0, 0.001)); // +25.0%
    });

    test('Negative MoM change preserves signed negative values', () {
      final expenses = [
        // Current month: ₹8,000 = 800,000 paise
        createTestExpense(
          id: 'curr-1',
          amountPaise: 800000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 15),
        ),
        // Previous month: ₹10,000 = 1,000,000 paise
        createTestExpense(
          id: 'prev-1',
          amountPaise: 1000000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 8, 15),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);

      expect(analytics.currentMonthTotalPaise, 800000);
      expect(analytics.previousMonthTotalPaise, 1000000);
      expect(analytics.monthOverMonthChangePaise, -200000); // -₹2,000
      expect(analytics.monthOverMonthChangePercent, closeTo(-20.0, 0.001)); // -20%
    });

    test('Calendar month boundaries (half-open intervals) strictly observed', () {
      final expenses = [
        // 1. Exactly at previous month start: 2026-08-01 00:00:00
        createTestExpense(
          id: 'prev-start',
          amountPaise: 10000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 8, 1, 0, 0, 0),
        ),
        // 2. Exactly at previous month end / current month start: 2026-09-01 00:00:00
        createTestExpense(
          id: 'curr-start',
          amountPaise: 20000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 1, 0, 0, 0),
        ),
        // 3. Last millisecond of current month: 2026-09-30 23:59:59.999
        createTestExpense(
          id: 'curr-end',
          amountPaise: 30000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 30, 23, 59, 59, 999),
        ),
        // 4. Exactly at next month start: 2026-10-01 00:00:00 (excluded from current month)
        createTestExpense(
          id: 'next-start',
          amountPaise: 40000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 10, 1, 0, 0, 0),
        ),
        // 5. Older than previous month: 2026-07-31 23:59:59 (excluded from both)
        createTestExpense(
          id: 'older',
          amountPaise: 50000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 7, 31, 23, 59, 59),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);

      expect(analytics.previousMonthTotalPaise, 10000);
      expect(analytics.previousMonthExpenseCount, 1);

      expect(analytics.currentMonthTotalPaise, 50000); // 20000 + 30000
      expect(analytics.currentMonthExpenseCount, 2);
    });

    test('Year boundary handling (January -> December)', () {
      final janNow = DateTime(2027, 1, 15, 10, 0);

      final expenses = [
        // December 2026 (previous month)
        createTestExpense(
          id: 'dec-1',
          amountPaise: 45000,
          category: ExpenseCategory.shopping,
          expenseDate: DateTime(2026, 12, 20),
        ),
        // January 2027 (current month)
        createTestExpense(
          id: 'jan-1',
          amountPaise: 75000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2027, 1, 5),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: janNow);

      expect(analytics.currentPeriodStart, DateTime(2027, 1, 1));
      expect(analytics.currentPeriodEnd, DateTime(2027, 2, 1));
      expect(analytics.previousPeriodStart, DateTime(2026, 12, 1));
      expect(analytics.previousPeriodEnd, DateTime(2027, 1, 1));

      expect(analytics.currentMonthTotalPaise, 75000);
      expect(analytics.currentMonthExpenseCount, 1);
      expect(analytics.previousMonthTotalPaise, 45000);
      expect(analytics.previousMonthExpenseCount, 1);
      expect(analytics.monthOverMonthChangePaise, 30000);
      expect(analytics.monthOverMonthChangePercent, closeTo(66.666, 0.001));
    });

    test('Category totals tie-breaking sorts alphabetically by displayName', () {
      final expenses = [
        createTestExpense(
          id: '1',
          amountPaise: 50000,
          category: ExpenseCategory.transport, // "Transport"
          expenseDate: DateTime(2026, 9, 2),
        ),
        createTestExpense(
          id: '2',
          amountPaise: 50000,
          category: ExpenseCategory.bills, // "Bills"
          expenseDate: DateTime(2026, 9, 3),
        ),
        createTestExpense(
          id: '3',
          amountPaise: 50000,
          category: ExpenseCategory.education, // "Education"
          expenseDate: DateTime(2026, 9, 4),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);

      expect(analytics.topCategory, ExpenseCategory.bills);
      expect(analytics.categoryTotals.map((c) => c.category).toList(), [
        ExpenseCategory.bills, // "Bills"
        ExpenseCategory.education, // "Education"
        ExpenseCategory.transport, // "Transport"
      ]);
    });

    test('Largest expense deterministic tie-breaking (amount desc -> date desc -> createdAt desc -> id asc)', () {
      final baseDate = DateTime(2026, 9, 10);
      final earlierDate = DateTime(2026, 9, 5);

      // Same amount, different dates
      final expDateTest = deriveSpendingAnalytics([
        createTestExpense(
          id: 'exp-early',
          amountPaise: 50000,
          category: ExpenseCategory.food,
          expenseDate: earlierDate,
        ),
        createTestExpense(
          id: 'exp-late',
          amountPaise: 50000,
          category: ExpenseCategory.food,
          expenseDate: baseDate,
        ),
      ], now: referenceNow);
      expect(expDateTest.largestExpense?.id, 'exp-late');

      // Same amount & date, different createdAt
      final expCreatedTest = deriveSpendingAnalytics([
        createTestExpense(
          id: 'exp-first',
          amountPaise: 50000,
          category: ExpenseCategory.food,
          expenseDate: baseDate,
          createdAt: DateTime(2026, 9, 10, 10, 0),
        ),
        createTestExpense(
          id: 'exp-second',
          amountPaise: 50000,
          category: ExpenseCategory.food,
          expenseDate: baseDate,
          createdAt: DateTime(2026, 9, 10, 12, 0),
        ),
      ], now: referenceNow);
      expect(expCreatedTest.largestExpense?.id, 'exp-second');

      // Same amount, date & createdAt, different id (alphabetical ascending)
      final expIdTest = deriveSpendingAnalytics([
        createTestExpense(
          id: 'exp-z',
          amountPaise: 50000,
          category: ExpenseCategory.food,
          expenseDate: baseDate,
          createdAt: DateTime(2026, 9, 10, 10, 0),
        ),
        createTestExpense(
          id: 'exp-a',
          amountPaise: 50000,
          category: ExpenseCategory.food,
          expenseDate: baseDate,
          createdAt: DateTime(2026, 9, 10, 10, 0),
        ),
      ], now: referenceNow);
      expect(expIdTest.largestExpense?.id, 'exp-a');
    });

    test('Historical expenseDate is classified by expenseDate, not createdAt', () {
      final expenses = [
        // Created today in September, but expenseDate was in August
        createTestExpense(
          id: 'hist-1',
          amountPaise: 70000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 8, 20),
          createdAt: DateTime(2026, 9, 17, 10, 0),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);

      expect(analytics.currentMonthTotalPaise, 0);
      expect(analytics.currentMonthExpenseCount, 0);
      expect(analytics.previousMonthTotalPaise, 70000);
      expect(analytics.previousMonthExpenseCount, 1);
    });

    test('Average calculation rounding follows deterministic integer half-up formula', () {
      // 3 items: 100 + 100 + 101 = 301 paise -> avg = 301/3 = 100.33 -> 100
      final test1 = deriveSpendingAnalytics([
        createTestExpense(id: '1', amountPaise: 100, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 1)),
        createTestExpense(id: '2', amountPaise: 100, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 2)),
        createTestExpense(id: '3', amountPaise: 101, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 3)),
      ], now: referenceNow);
      expect(test1.averageExpensePaise, 100);

      // 3 items: 100 + 100 + 102 = 302 paise -> avg = 302/3 = 100.66 -> 101
      final test2 = deriveSpendingAnalytics([
        createTestExpense(id: '1', amountPaise: 100, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 1)),
        createTestExpense(id: '2', amountPaise: 100, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 2)),
        createTestExpense(id: '3', amountPaise: 102, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 3)),
      ], now: referenceNow);
      expect(test2.averageExpensePaise, 101);

      // 2 items: 100 + 101 = 201 paise -> avg = 201/2 = 100.5 -> 101 (half-up)
      final test3 = deriveSpendingAnalytics([
        createTestExpense(id: '1', amountPaise: 100, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 1)),
        createTestExpense(id: '2', amountPaise: 101, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 2)),
      ], now: referenceNow);
      expect(test3.averageExpensePaise, 101);
    });

    test('Large integer paise amounts are preserved without overflow or floating-point drift', () {
      final expenses = [
        createTestExpense(
          id: 'large-1',
          amountPaise: 500000000, // ₹50,00,000
          category: ExpenseCategory.education,
          expenseDate: DateTime(2026, 9, 5),
        ),
        createTestExpense(
          id: 'large-2',
          amountPaise: 300000075, // ₹30,00,000.75
          category: ExpenseCategory.health,
          expenseDate: DateTime(2026, 9, 10),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);

      expect(analytics.currentMonthTotalPaise, 800000075);
      expect(analytics.averageExpensePaise, 400000038); // (800000075 + 1) ~/ 2
    });

    test('Recent expenses list returns top 5 in deterministic descending order without mutating input', () {
      final expenses = List.generate(8, (i) {
        return createTestExpense(
          id: 'exp-$i',
          amountPaise: (i + 1) * 1000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, i + 1),
        );
      });

      final originalOrderIds = expenses.map((e) => e.id).toList();

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);

      expect(analytics.recentExpenses.length, 5);
      expect(analytics.recentExpenses.map((e) => e.id).toList(), [
        'exp-7',
        'exp-6',
        'exp-5',
        'exp-4',
        'exp-3',
      ]);

      // Verify input list was not mutated
      expect(expenses.map((e) => e.id).toList(), originalOrderIds);
    });

    test('Local date time interpretation preserves calendar semantics', () {
      // Local DateTime at midnight
      final localMidnight = DateTime(2026, 9, 1, 0, 0, 0);
      final expense = createTestExpense(
        id: 'local-1',
        amountPaise: 10000,
        category: ExpenseCategory.food,
        expenseDate: localMidnight,
      );

      final analytics = deriveSpendingAnalytics([expense], now: referenceNow);
      expect(analytics.currentMonthExpenseCount, 1);
      expect(analytics.currentMonthTotalPaise, 10000);
    });
  });
}

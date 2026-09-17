import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends_calculator.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
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

  group('SpendingTrendsCalculator Tests', () {
    test('Empty data yields empty collections and null highest spending day', () {
      final trends = deriveSpendingTrends([]);

      expect(trends.dailySpending, isEmpty);
      expect(trends.weeklySpending, isEmpty);
      expect(trends.monthlySpending, isEmpty);
      expect(trends.categoryTrends, isEmpty);
      expect(trends.highestSpendingDay, isNull);
    });

    test('Daily spending aggregates same-day expenses and orders chronologically', () {
      final expenses = [
        // Day 2: 2026-09-12
        createTestExpense(
          id: 'exp-2a',
          amountPaise: 15000, // ₹150
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 12, 10, 0),
        ),
        // Day 1: 2026-09-10 (Two expenses)
        createTestExpense(
          id: 'exp-1a',
          amountPaise: 20000, // ₹200
          category: ExpenseCategory.transport,
          expenseDate: DateTime(2026, 9, 10, 8, 30),
        ),
        createTestExpense(
          id: 'exp-1b',
          amountPaise: 30000, // ₹300
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 10, 20, 15),
        ),
        // Day 3: 2026-09-15
        createTestExpense(
          id: 'exp-3a',
          amountPaise: 80000, // ₹800
          category: ExpenseCategory.shopping,
          expenseDate: DateTime(2026, 9, 15, 14, 0),
        ),
      ];

      final trends = deriveSpendingTrends(expenses);

      expect(trends.dailySpending.length, 3);

      // Point 1: 2026-09-10 -> 20000 + 30000 = 50000 paise
      expect(trends.dailySpending[0].periodStart, DateTime(2026, 9, 10));
      expect(trends.dailySpending[0].periodEnd, DateTime(2026, 9, 11));
      expect(trends.dailySpending[0].totalAmountPaise, 50000);

      // Point 2: 2026-09-12 -> 15000 paise
      expect(trends.dailySpending[1].periodStart, DateTime(2026, 9, 12));
      expect(trends.dailySpending[1].periodEnd, DateTime(2026, 9, 13));
      expect(trends.dailySpending[1].totalAmountPaise, 15000);

      // Point 3: 2026-09-15 -> 80000 paise
      expect(trends.dailySpending[2].periodStart, DateTime(2026, 9, 15));
      expect(trends.dailySpending[2].periodEnd, DateTime(2026, 9, 16));
      expect(trends.dailySpending[2].totalAmountPaise, 80000);
    });

    test('Daily boundary respects half-open intervals [day 00:00, next day 00:00)', () {
      final expenses = [
        // Exact midnight start of Day 10
        createTestExpense(
          id: 'day10-start',
          amountPaise: 10000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 10, 0, 0, 0, 0),
        ),
        // Last moment of Day 10
        createTestExpense(
          id: 'day10-end',
          amountPaise: 20000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 10, 23, 59, 59, 999),
        ),
        // Midnight start of Day 11
        createTestExpense(
          id: 'day11-start',
          amountPaise: 30000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 11, 0, 0, 0, 0),
        ),
      ];

      final trends = deriveSpendingTrends(expenses);

      expect(trends.dailySpending.length, 2);
      expect(trends.dailySpending[0].periodStart, DateTime(2026, 9, 10));
      expect(trends.dailySpending[0].totalAmountPaise, 30000); // 10000 + 20000

      expect(trends.dailySpending[1].periodStart, DateTime(2026, 9, 11));
      expect(trends.dailySpending[1].totalAmountPaise, 30000);
    });

    test('Weekly aggregation strictly follows Monday-Sunday calendar weeks', () {
      final expenses = [
        // Sunday 2026-09-06 (Week: 2026-08-31 to 2026-09-07)
        createTestExpense(
          id: 'sun-w1',
          amountPaise: 40000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 6, 22, 0),
        ),
        // Monday 2026-09-07 (Week: 2026-09-07 to 2026-09-14)
        createTestExpense(
          id: 'mon-w2',
          amountPaise: 15000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 7, 9, 0),
        ),
        // Wednesday 2026-09-09 (Week: 2026-09-07 to 2026-09-14)
        createTestExpense(
          id: 'wed-w2',
          amountPaise: 25000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 9, 14, 0),
        ),
        // Sunday 2026-09-13 (Week: 2026-09-07 to 2026-09-14)
        createTestExpense(
          id: 'sun-w2',
          amountPaise: 35000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 13, 23, 30),
        ),
        // Monday 2026-09-14 (Week: 2026-09-14 to 2026-09-21)
        createTestExpense(
          id: 'mon-w3',
          amountPaise: 50000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 14, 8, 0),
        ),
      ];

      final trends = deriveSpendingTrends(expenses);

      expect(trends.weeklySpending.length, 3);

      // Week 1: 2026-08-31 (Monday) to 2026-09-07 (Monday)
      expect(trends.weeklySpending[0].periodStart, DateTime(2026, 8, 31));
      expect(trends.weeklySpending[0].periodEnd, DateTime(2026, 9, 7));
      expect(trends.weeklySpending[0].totalAmountPaise, 40000);

      // Week 2: 2026-09-07 to 2026-09-14 -> 15000 + 25000 + 35000 = 75000
      expect(trends.weeklySpending[1].periodStart, DateTime(2026, 9, 7));
      expect(trends.weeklySpending[1].periodEnd, DateTime(2026, 9, 14));
      expect(trends.weeklySpending[1].totalAmountPaise, 75000);

      // Week 3: 2026-09-14 to 2026-09-21
      expect(trends.weeklySpending[2].periodStart, DateTime(2026, 9, 14));
      expect(trends.weeklySpending[2].periodEnd, DateTime(2026, 9, 21));
      expect(trends.weeklySpending[2].totalAmountPaise, 50000);
    });

    test('Monthly aggregation handles multiple months and year transitions', () {
      final expenses = [
        // November 2026
        createTestExpense(
          id: 'nov-26',
          amountPaise: 200000, // ₹2000
          category: ExpenseCategory.bills,
          expenseDate: DateTime(2026, 11, 15),
        ),
        // December 2026
        createTestExpense(
          id: 'dec-26',
          amountPaise: 350000, // ₹3500
          category: ExpenseCategory.shopping,
          expenseDate: DateTime(2026, 12, 25),
        ),
        // January 2027
        createTestExpense(
          id: 'jan-27',
          amountPaise: 400000, // ₹4000
          category: ExpenseCategory.food,
          expenseDate: DateTime(2027, 1, 10),
        ),
      ];

      final trends = deriveSpendingTrends(expenses);

      expect(trends.monthlySpending.length, 3);

      expect(trends.monthlySpending[0].periodStart, DateTime(2026, 11, 1));
      expect(trends.monthlySpending[0].periodEnd, DateTime(2026, 12, 1));
      expect(trends.monthlySpending[0].totalAmountPaise, 200000);

      expect(trends.monthlySpending[1].periodStart, DateTime(2026, 12, 1));
      expect(trends.monthlySpending[1].periodEnd, DateTime(2027, 1, 1));
      expect(trends.monthlySpending[1].totalAmountPaise, 350000);

      expect(trends.monthlySpending[2].periodStart, DateTime(2027, 1, 1));
      expect(trends.monthlySpending[2].periodEnd, DateTime(2027, 2, 1));
      expect(trends.monthlySpending[2].totalAmountPaise, 400000);
    });

    test('Leap year February aggregation (2024 leap year vs 2023 non-leap year)', () {
      final expenses = [
        // Feb 29 on 2024 leap year
        createTestExpense(
          id: 'leap-feb-29',
          amountPaise: 120000,
          category: ExpenseCategory.entertainment,
          expenseDate: DateTime(2024, 2, 29, 18, 0),
        ),
        // Feb 28 on 2023 non-leap year
        createTestExpense(
          id: 'non-leap-feb-28',
          amountPaise: 90000,
          category: ExpenseCategory.entertainment,
          expenseDate: DateTime(2023, 2, 28, 18, 0),
        ),
      ];

      final trends = deriveSpendingTrends(expenses);

      expect(trends.monthlySpending.length, 2);

      // 2023 February
      expect(trends.monthlySpending[0].periodStart, DateTime(2023, 2, 1));
      expect(trends.monthlySpending[0].periodEnd, DateTime(2023, 3, 1));
      expect(trends.monthlySpending[0].totalAmountPaise, 90000);

      // 2024 February (Leap)
      expect(trends.monthlySpending[1].periodStart, DateTime(2024, 2, 1));
      expect(trends.monthlySpending[1].periodEnd, DateTime(2024, 3, 1));
      expect(trends.monthlySpending[1].totalAmountPaise, 120000);

      // Daily point for Feb 29 ends on Mar 1
      final leapDailyPoint = trends.dailySpending.firstWhere(
        (p) => p.periodStart == DateTime(2024, 2, 29),
      );
      expect(leapDailyPoint.periodEnd, DateTime(2024, 3, 1));
    });

    test('Category trends aggregate over time and sort categories alphabetically by displayName', () {
      final expenses = [
        createTestExpense(
          id: 'trans-1',
          amountPaise: 10000,
          category: ExpenseCategory.transport, // "Transport"
          expenseDate: DateTime(2026, 9, 5),
        ),
        createTestExpense(
          id: 'bills-1',
          amountPaise: 50000,
          category: ExpenseCategory.bills, // "Bills"
          expenseDate: DateTime(2026, 9, 3),
        ),
        createTestExpense(
          id: 'food-1',
          amountPaise: 20000,
          category: ExpenseCategory.food, // "Food"
          expenseDate: DateTime(2026, 9, 2),
        ),
        createTestExpense(
          id: 'food-2',
          amountPaise: 30000,
          category: ExpenseCategory.food, // "Food"
          expenseDate: DateTime(2026, 9, 6),
        ),
      ];

      final trends = deriveSpendingTrends(expenses);

      expect(trends.categoryTrends.length, 3);
      // Alphabetical order: Bills, Food, Transport
      expect(trends.categoryTrends[0].category, ExpenseCategory.bills);
      expect(trends.categoryTrends[1].category, ExpenseCategory.food);
      expect(trends.categoryTrends[2].category, ExpenseCategory.transport);

      // Food category points (2 days, chronological)
      final foodPoints = trends.categoryTrends[1].points;
      expect(foodPoints.length, 2);
      expect(foodPoints[0].periodStart, DateTime(2026, 9, 2));
      expect(foodPoints[0].totalAmountPaise, 20000);
      expect(foodPoints[1].periodStart, DateTime(2026, 9, 6));
      expect(foodPoints[1].totalAmountPaise, 30000);
    });

    test('Highest spending day resolves max and tie-breaks in favor of more recent day', () {
      // Distinct max
      final distinctMaxExpenses = [
        createTestExpense(
          id: 'd1',
          amountPaise: 30000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 5),
        ),
        createTestExpense(
          id: 'd2',
          amountPaise: 80000, // Max
          category: ExpenseCategory.shopping,
          expenseDate: DateTime(2026, 9, 8),
        ),
      ];
      final trends1 = deriveSpendingTrends(distinctMaxExpenses);
      expect(trends1.highestSpendingDay?.date, DateTime(2026, 9, 8));
      expect(trends1.highestSpendingDay?.totalAmountPaise, 80000);

      // Equal total amount tie: Day 5 and Day 15 both have 60000 paise -> Day 15 wins
      final tieExpenses = [
        createTestExpense(
          id: 'tie-1',
          amountPaise: 60000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 5, 10, 0),
        ),
        createTestExpense(
          id: 'tie-2',
          amountPaise: 60000,
          category: ExpenseCategory.shopping,
          expenseDate: DateTime(2026, 9, 15, 14, 0),
        ),
      ];
      final trends2 = deriveSpendingTrends(tieExpenses);
      expect(trends2.highestSpendingDay?.date, DateTime(2026, 9, 15));
      expect(trends2.highestSpendingDay?.totalAmountPaise, 60000);
    });

    test('Historical expenseDate is classified by expenseDate, not createdAt', () {
      final expenses = [
        createTestExpense(
          id: 'hist-1',
          amountPaise: 75000,
          category: ExpenseCategory.health,
          expenseDate: DateTime(2026, 8, 15),
          createdAt: DateTime(2026, 9, 17, 12, 0),
        ),
      ];

      final trends = deriveSpendingTrends(expenses);

      expect(trends.dailySpending.first.periodStart, DateTime(2026, 8, 15));
      expect(trends.monthlySpending.first.periodStart, DateTime(2026, 8, 1));
    });

    test('Large integer paise amounts preserve precision without floating-point errors', () {
      final expenses = [
        createTestExpense(
          id: 'large-1',
          amountPaise: 1000000050, // ₹1,00,00,000.50
          category: ExpenseCategory.education,
          expenseDate: DateTime(2026, 9, 1),
        ),
        createTestExpense(
          id: 'large-2',
          amountPaise: 2000000025, // ₹2,00,00,000.25
          category: ExpenseCategory.education,
          expenseDate: DateTime(2026, 9, 1),
        ),
      ];

      final trends = deriveSpendingTrends(expenses);

      expect(trends.dailySpending.first.totalAmountPaise, 3000000075);
    });

    test('Input collection remains completely unmutated', () {
      final expenses = [
        createTestExpense(id: '3', amountPaise: 300, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 3)),
        createTestExpense(id: '1', amountPaise: 100, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 1)),
        createTestExpense(id: '2', amountPaise: 200, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 2)),
      ];

      final originalIds = expenses.map((e) => e.id).toList();

      deriveSpendingTrends(expenses);

      expect(expenses.map((e) => e.id).toList(), originalIds);
    });

    test('Deterministic execution across multiple runs', () {
      final expenses = [
        createTestExpense(id: 'a', amountPaise: 5000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 5)),
        createTestExpense(id: 'b', amountPaise: 7000, category: ExpenseCategory.transport, expenseDate: DateTime(2026, 9, 2)),
      ];

      final run1 = deriveSpendingTrends(expenses);
      final run2 = deriveSpendingTrends(expenses);

      expect(run1, equals(run2));
      expect(run1.hashCode, equals(run2.hashCode));
    });
  });
}

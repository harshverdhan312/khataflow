import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/spending_analytics_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insights_calculator.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends_calculator.dart';
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

  group('SpendingInsightsCalculator Tests', () {
    test('Empty state yields empty insights', () {
      final analytics = deriveSpendingAnalytics([], now: referenceNow);
      final trends = deriveSpendingTrends([]);
      final insights = deriveSpendingInsights(analytics: analytics, trends: trends);

      expect(insights.isEmpty, isTrue);
      expect(insights.hasInsights, isFalse);
      expect(insights.highestPriority, isNull);
      expect(insights.insights, isEmpty);
    });

    test('Spending increase (>= 20%) generates spendingIncrease insight (Medium priority)', () {
      final expenses = [
        // Current month: ₹12,500 = 1,250,000 paise
        createTestExpense(
          id: 'c1',
          amountPaise: 1250000,
          category: ExpenseCategory.shopping,
          expenseDate: DateTime(2026, 9, 10),
        ),
        // Previous month: ₹9,800 = 980,000 paise (+27.55% increase)
        createTestExpense(
          id: 'p1',
          amountPaise: 980000,
          category: ExpenseCategory.shopping,
          expenseDate: DateTime(2026, 8, 10),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);
      final trends = deriveSpendingTrends(expenses);
      final result = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );

      final increaseInsight = result.insights.firstWhere(
        (i) => i.type == InsightType.spendingIncrease,
      );
      expect(increaseInsight.priority, InsightPriority.medium);
      expect(increaseInsight.amountPaise, 270000); // 1250000 - 980000
      expect(increaseInsight.description, contains('more than last month'));
    });

    test('Spending decrease (>= 20%) generates spendingDecrease insight (Medium priority)', () {
      final expenses = [
        // Current month: ₹7,000 = 700,000 paise
        createTestExpense(
          id: 'c1',
          amountPaise: 700000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 10),
        ),
        // Previous month: ₹10,000 = 1,000,000 paise (-30.0% decrease)
        createTestExpense(
          id: 'p1',
          amountPaise: 1000000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 8, 10),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);
      final trends = deriveSpendingTrends(expenses);
      final result = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );

      final decreaseInsight = result.insights.firstWhere(
        (i) => i.type == InsightType.spendingDecrease,
      );
      expect(decreaseInsight.priority, InsightPriority.medium);
      expect(decreaseInsight.amountPaise, 300000);
      expect(decreaseInsight.description, contains('30% less than last month'));
    });

    test('Spending concentration (> 50%) generates High priority insight', () {
      final expenses = [
        createTestExpense(
          id: 'c1',
          amountPaise: 60000, // Food 60%
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 5),
        ),
        createTestExpense(
          id: 'c2',
          amountPaise: 40000, // Transport 40%
          category: ExpenseCategory.transport,
          expenseDate: DateTime(2026, 9, 8),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);
      final trends = deriveSpendingTrends(expenses);
      final result = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );

      final concentration = result.insights.firstWhere(
        (i) => i.type == InsightType.spendingConcentration,
      );
      expect(concentration.priority, InsightPriority.high);
      expect(concentration.category, ExpenseCategory.food);
      expect(concentration.description, contains('More than half your spending was in Food'));
      // High priority item is ranked first
      expect(result.highestPriority, concentration);
    });

    test('Largest expense & Top category generate structured insights', () {
      final expenses = [
        createTestExpense(
          id: 'c1',
          amountPaise: 250000, // ₹2,500 on Shopping
          category: ExpenseCategory.shopping,
          expenseDate: DateTime(2026, 9, 12),
        ),
        createTestExpense(
          id: 'c2',
          amountPaise: 50000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 14),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);
      final trends = deriveSpendingTrends(expenses);
      final result = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );

      final largest = result.insights.firstWhere((i) => i.type == InsightType.largestExpense);
      expect(largest.amountPaise, 250000);
      expect(largest.category, ExpenseCategory.shopping);
      expect(largest.date, DateTime(2026, 9, 12));

      final topCat = result.insights.firstWhere((i) => i.type == InsightType.topCategory);
      expect(topCat.category, ExpenseCategory.shopping);
    });

    test('Highest spending day integrates from trends', () {
      final expenses = [
        createTestExpense(
          id: 'c1',
          amountPaise: 185000, // ₹1,850 on Sep 15
          category: ExpenseCategory.bills,
          expenseDate: DateTime(2026, 9, 15, 12, 0),
        ),
        createTestExpense(
          id: 'c2',
          amountPaise: 30000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 10, 10, 0),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);
      final trends = deriveSpendingTrends(expenses);
      final result = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );

      final highDay = result.insights.firstWhere((i) => i.type == InsightType.unusuallyHighDay);
      expect(highDay.amountPaise, 185000);
      expect(highDay.date, DateTime(2026, 9, 15));
      expect(highDay.description, contains('15 Sep'));
    });

    test('Category growth (>= 30%) and category drop (<= -30%) generate insights', () {
      final expenses = [
        // Current: Transport ₹1,400 (140000 paise), Food ₹200 (20000 paise)
        createTestExpense(
          id: 'c-trans',
          amountPaise: 140000,
          category: ExpenseCategory.transport,
          expenseDate: DateTime(2026, 9, 5),
        ),
        createTestExpense(
          id: 'c-food',
          amountPaise: 20000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 9, 6),
        ),
        // Previous: Transport ₹1,000 (+40% growth), Food ₹1,000 (-80% drop)
        createTestExpense(
          id: 'p-trans',
          amountPaise: 100000,
          category: ExpenseCategory.transport,
          expenseDate: DateTime(2026, 8, 5),
        ),
        createTestExpense(
          id: 'p-food',
          amountPaise: 100000,
          category: ExpenseCategory.food,
          expenseDate: DateTime(2026, 8, 6),
        ),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);
      final trends = deriveSpendingTrends(expenses);
      final result = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );

      final growth = result.insights.firstWhere((i) => i.type == InsightType.categoryGrowth);
      expect(growth.category, ExpenseCategory.transport);
      expect(growth.percentage, 40.0);

      final drop = result.insights.firstWhere((i) => i.type == InsightType.categoryDrop);
      expect(drop.category, ExpenseCategory.food);
      expect(drop.percentage, 80.0);
    });

    test('Frequent category (> 40% count) and High expense count (> 1.5x) generate insights', () {
      final expenses = [
        // Current month: 4 expenses (3 Food = 75% > 40%)
        createTestExpense(id: 'c1', amountPaise: 1000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 1)),
        createTestExpense(id: 'c2', amountPaise: 1000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 2)),
        createTestExpense(id: 'c3', amountPaise: 1000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 3)),
        createTestExpense(id: 'c4', amountPaise: 1000, category: ExpenseCategory.bills, expenseDate: DateTime(2026, 9, 4)),
        // Previous month: 2 expenses (4 vs 2 = 2.0x > 1.5x)
        createTestExpense(id: 'p1', amountPaise: 1000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 8, 1)),
        createTestExpense(id: 'p2', amountPaise: 1000, category: ExpenseCategory.bills, expenseDate: DateTime(2026, 8, 2)),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);
      final trends = deriveSpendingTrends(expenses);
      final result = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );

      final frequent = result.insights.firstWhere((i) => i.type == InsightType.frequentCategory);
      expect(frequent.category, ExpenseCategory.food);

      final countInsight = result.insights.firstWhere((i) => i.type == InsightType.highExpenseCount);
      expect(countInsight.description, contains('4 vs 2'));
    });

    test('Priority sorting orders High -> Medium -> Low deterministically', () {
      final expenses = [
        // Generates Concentration (High), Spending Increase (Medium), Top Category (Low), Largest (Low), etc.
        createTestExpense(id: 'c1', amountPaise: 800000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 5)),
        createTestExpense(id: 'c2', amountPaise: 200000, category: ExpenseCategory.transport, expenseDate: DateTime(2026, 9, 6)),
        createTestExpense(id: 'p1', amountPaise: 500000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 8, 5)),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);
      final trends = deriveSpendingTrends(expenses);
      final result = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );

      for (int i = 0; i < result.insights.length - 1; i++) {
        expect(
          result.insights[i].priority.rank <= result.insights[i + 1].priority.rank,
          isTrue,
          reason: 'Item $i (${result.insights[i].priority}) should rank before or equal to item ${i + 1} (${result.insights[i + 1].priority})',
        );
      }
    });

    test('Top 8 capping truncates results to at most 8 insights', () {
      final expenses = [
        // Current month with 6 different categories all with >30% growth and high count
        createTestExpense(id: 'c1', amountPaise: 600000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 1)),
        createTestExpense(id: 'c2', amountPaise: 50000, category: ExpenseCategory.transport, expenseDate: DateTime(2026, 9, 2)),
        createTestExpense(id: 'c3', amountPaise: 50000, category: ExpenseCategory.shopping, expenseDate: DateTime(2026, 9, 3)),
        createTestExpense(id: 'c4', amountPaise: 50000, category: ExpenseCategory.bills, expenseDate: DateTime(2026, 9, 4)),
        createTestExpense(id: 'c5', amountPaise: 50000, category: ExpenseCategory.entertainment, expenseDate: DateTime(2026, 9, 5)),
        createTestExpense(id: 'c6', amountPaise: 50000, category: ExpenseCategory.health, expenseDate: DateTime(2026, 9, 6)),
        createTestExpense(id: 'c7', amountPaise: 50000, category: ExpenseCategory.education, expenseDate: DateTime(2026, 9, 7)),
        // Previous month with tiny values for each
        createTestExpense(id: 'p1', amountPaise: 10000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 8, 1)),
        createTestExpense(id: 'p2', amountPaise: 10000, category: ExpenseCategory.transport, expenseDate: DateTime(2026, 8, 2)),
        createTestExpense(id: 'p3', amountPaise: 10000, category: ExpenseCategory.shopping, expenseDate: DateTime(2026, 8, 3)),
        createTestExpense(id: 'p4', amountPaise: 10000, category: ExpenseCategory.bills, expenseDate: DateTime(2026, 8, 4)),
        createTestExpense(id: 'p5', amountPaise: 10000, category: ExpenseCategory.entertainment, expenseDate: DateTime(2026, 8, 5)),
      ];

      final analytics = deriveSpendingAnalytics(expenses, now: referenceNow);
      final trends = deriveSpendingTrends(expenses);
      final result = deriveSpendingInsights(
        analytics: analytics,
        trends: trends,
        expenses: expenses,
      );

      expect(result.insights.length, lessThanOrEqualTo(8));
    });

    test('Exact integer arithmetic boundaries for rules', () {
      // 1. Exact 20% increase: current = 12000, previous = 10000 (12000 * 5 == 10000 * 6 == 60000)
      final expExact20 = [
        createTestExpense(id: 'c1', amountPaise: 12000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 1)),
        createTestExpense(id: 'p1', amountPaise: 10000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 8, 1)),
      ];
      final rExact20 = deriveSpendingInsights(
        analytics: deriveSpendingAnalytics(expExact20, now: referenceNow),
        trends: deriveSpendingTrends(expExact20),
        expenses: expExact20,
      );
      expect(rExact20.insights.any((i) => i.type == InsightType.spendingIncrease), isTrue);

      // 2. 19.9% increase: current = 11990, previous = 10000 (11990 * 5 = 59950 < 60000)
      final expBelow20 = [
        createTestExpense(id: 'c1', amountPaise: 11990, category: ExpenseCategory.food, expenseDate: DateTime(2026, 9, 1)),
        createTestExpense(id: 'p1', amountPaise: 10000, category: ExpenseCategory.food, expenseDate: DateTime(2026, 8, 1)),
      ];
      final rBelow20 = deriveSpendingInsights(
        analytics: deriveSpendingAnalytics(expBelow20, now: referenceNow),
        trends: deriveSpendingTrends(expBelow20),
        expenses: expBelow20,
      );
      expect(rBelow20.insights.any((i) => i.type == InsightType.spendingIncrease), isFalse);

      // 3. Exact 30% category growth: current = 13000, previous = 10000 (13000 * 10 == 10000 * 13 == 130000)
      final expExact30Cat = [
        createTestExpense(id: 'c1', amountPaise: 13000, category: ExpenseCategory.transport, expenseDate: DateTime(2026, 9, 1)),
        createTestExpense(id: 'p1', amountPaise: 10000, category: ExpenseCategory.transport, expenseDate: DateTime(2026, 8, 1)),
      ];
      final rExact30Cat = deriveSpendingInsights(
        analytics: deriveSpendingAnalytics(expExact30Cat, now: referenceNow),
        trends: deriveSpendingTrends(expExact30Cat),
        expenses: expExact30Cat,
      );
      expect(rExact30Cat.insights.any((i) => i.type == InsightType.categoryGrowth), isTrue);
    });
  });
}

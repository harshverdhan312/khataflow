import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/utils/currency_formatter.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/insight_priority.dart';
import 'package:khata_flow/features/expense/domain/models/insight_type.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insight.dart';
import 'package:khata_flow/features/expense/presentation/utils/spending_insight_presenter.dart';

void main() {
  group('SpendingInsightPresenter Tests', () {
    test('All 10 InsightType values return non-null IconData and Accent Color', () {
      for (final type in InsightType.values) {
        final icon = SpendingInsightPresenter.getIcon(type);
        expect(icon, isA<IconData>(), reason: '$type should have valid IconData');

        final color = SpendingInsightPresenter.getAccentColor(type);
        expect(color, isA<Color>(), reason: '$type should have valid Color');
      }
    });

    test('getSupportingMetric formats amountPaise using CurrencyFormatter', () {
      const insight = SpendingInsight(
        type: InsightType.largestExpense,
        priority: InsightPriority.low,
        title: 'Largest Expense',
        description: 'Largest expense in Shopping',
        amountPaise: 250000, // ₹2,500
      );

      final metric = SpendingInsightPresenter.getSupportingMetric(insight);
      expect(metric, CurrencyFormatter.formatPaise(250000));
      expect(metric, '₹2,500');
    });

    test('getSupportingMetric formats percentage when amountPaise is null', () {
      const insight = SpendingInsight(
        type: InsightType.spendingIncrease,
        priority: InsightPriority.medium,
        title: 'Spending Increase',
        description: 'Spent 28% more',
        percentage: 28.4,
      );

      final metric = SpendingInsightPresenter.getSupportingMetric(insight);
      expect(metric, '28%');
    });

    test('getSupportingMetric formats date when amount and percentage are null', () {
      final date = DateTime(2026, 9, 15);
      final insight = SpendingInsight(
        type: InsightType.unusuallyHighDay,
        priority: InsightPriority.low,
        title: 'Highest Spending Day',
        description: 'Highest day',
        date: date,
      );

      final metric = SpendingInsightPresenter.getSupportingMetric(insight);
      expect(metric, '15 Sep');
    });

    test('getSupportingMetric returns null when no supporting metrics exist', () {
      const insight = SpendingInsight(
        type: InsightType.frequentCategory,
        priority: InsightPriority.low,
        title: 'Frequent Category',
        description: 'Food was frequent',
        category: ExpenseCategory.food,
      );

      final metric = SpendingInsightPresenter.getSupportingMetric(insight);
      expect(metric, isNull);
    });
  });
}

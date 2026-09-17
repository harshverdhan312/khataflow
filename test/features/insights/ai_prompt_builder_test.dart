import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/expense/domain/models/category_spending.dart';
import 'package:khata_flow/features/expense/domain/models/insight_priority.dart';
import 'package:khata_flow/features/expense/domain/models/insight_type.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insight.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insights.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trend_point.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends.dart';
import 'package:khata_flow/features/insights/data/prompt/ai_prompt_builder.dart';
import 'package:khata_flow/features/insights/domain/models/ai_context.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_request.dart';
import 'package:khata_flow/features/insights/domain/models/ai_request_type.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  group('AiPromptBuilder Tests', () {
    const builder = AiPromptBuilder();
    final now = DateTime(2026, 9, 15);

    final testExpense = Expense(
      id: 'secret_exp_id_99999',
      amountPaise: 350000,
      category: ExpenseCategory.food,
      note: 'Family dinner',
      expenseDate: DateTime(2026, 9, 10),
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
    );

    final context = AIContext(
      periodStart: DateTime(2026, 9, 1),
      periodEnd: DateTime(2026, 10, 1),
      currentMonthTotalPaise: 750000,
      previousMonthTotalPaise: 500000,
      currentMonthExpenseCount: 14,
      previousMonthExpenseCount: 10,
      categoryTotals: const [
        CategorySpending(category: ExpenseCategory.food, totalAmountPaise: 450000),
        CategorySpending(category: ExpenseCategory.transport, totalAmountPaise: 300000),
      ],
      topCategory: ExpenseCategory.food,
      largestExpense: testExpense,
      recentExpenses: [testExpense],
      ruleBasedInsights: const SpendingInsights(
        insights: [
          SpendingInsight(
            type: InsightType.spendingIncrease,
            priority: InsightPriority.high,
            title: 'Spending Increased',
            description: 'You spent 50% more than last month',
            percentage: 50.0,
          ),
        ],
      ),
      spendingTrends: SpendingTrends(
        dailySpending: [
          SpendingTrendPoint(
            periodStart: DateTime(2026, 9, 10),
            periodEnd: DateTime(2026, 9, 11),
            totalAmountPaise: 350000,
          ),
        ],
        weeklySpending: const [],
        monthlySpending: const [],
        categoryTrends: const [],
        highestSpendingDay: HighestSpendingDay(
          date: DateTime(2026, 9, 10),
          totalAmountPaise: 350000,
        ),
      ),
    );

    test('buildPromptText enforces data minimization: NO database IDs or private metadata', () {
      final request = AIInsightRequest(
        context: context,
        requestType: AIRequestType.monthlySummary,
      );

      final prompt = builder.buildPromptText(request);

      // Verify NO database internal identifiers exist in the prompt
      expect(prompt.contains('secret_exp_id_99999'), isFalse);
      expect(prompt.contains('syncStatus'), isFalse);
      expect(prompt.contains('createdAt'), isFalse);
      expect(prompt.contains('updatedAt'), isFalse);

      // Verify authorized financial data IS present
      expect(prompt.contains('₹7,500'), isTrue);
      expect(prompt.contains('₹5,000'), isTrue);
      expect(prompt.contains('Food'), isTrue);
      expect(prompt.contains('Spending Increased'), isTrue);
      expect(prompt.contains('Highest Spending Day'), isTrue);
    });

    test('buildPromptText accurately distinguishes monthlySummary vs spendingAdvice', () {
      final summaryRequest = AIInsightRequest(
        context: context,
        requestType: AIRequestType.monthlySummary,
      );
      final adviceRequest = AIInsightRequest(
        context: context,
        requestType: AIRequestType.spendingAdvice,
      );

      final summaryPrompt = builder.buildPromptText(summaryRequest);
      final advicePrompt = builder.buildPromptText(adviceRequest);

      expect(summaryPrompt.contains('MONTHLY SPENDING SUMMARY'), isTrue);
      expect(summaryPrompt.contains('SPENDING ADVICE'), isFalse);

      expect(advicePrompt.contains('SPENDING ADVICE'), isTrue);
      expect(advicePrompt.contains('MONTHLY SPENDING SUMMARY'), isFalse);
    });

    test('buildRequestPayload produces valid JSON payload envelope with temperature and schema config', () {
      final request = AIInsightRequest(
        context: context,
        requestType: AIRequestType.monthlySummary,
      );

      final jsonPayload = builder.buildRequestPayload(request);
      final decoded = jsonDecode(jsonPayload) as Map<String, dynamic>;

      expect(decoded.containsKey('contents'), isTrue);
      expect(decoded['contents'], isList);
      expect(decoded['generationConfig']['responseMimeType'], 'application/json');
      expect(decoded['generationConfig']['temperature'], 0.2);
    });
  });
}

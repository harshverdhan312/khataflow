import 'dart:convert';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/ai_insight_request.dart';
import '../../domain/models/ai_request_type.dart';

/// Service responsible for constructing structured, data-minimized prompts for AI insight generation.
class AiPromptBuilder {
  const AiPromptBuilder();

  /// Builds the complete JSON request payload for the AI model.
  String buildRequestPayload(AIInsightRequest request) {
    final promptText = buildPromptText(request);

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': promptText},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
      },
    };

    return jsonEncode(payload);
  }

  /// Builds the raw text instructions and serialized financial context.
  String buildPromptText(AIInsightRequest request) {
    final context = request.context;
    final buffer = StringBuffer();

    // 1. System Role & Critical Invariants
    buffer.writeln('You are KhataFlow Intelligence, a trusted, privacy-first personal financial advisor.');
    buffer.writeln('CRITICAL INSTRUCTIONS:');
    buffer.writeln('1. The financial figures provided below are authoritative and verified. DO NOT recalculate, modify, or dispute them.');
    buffer.writeln('2. DO NOT invent, hallucinate, or assume expenses, transactions, habits, or external causes not present in the data.');
    buffer.writeln('3. Keep your analysis concise, empathetic, practical, and grounded solely in the provided context.');
    buffer.writeln('4. Output strictly valid JSON matching this schema:');
    buffer.writeln('{\n  "title": "Short punchy insight title (under 100 chars)",\n  "explanation": "Clear, grounded explanation of what the data shows (1-3 sentences)",\n  "recommendation": "Actionable, non-judgmental guidance for the user (1-2 sentences)",\n  "supportingInsightType": "Optional InsightType string matching rule-based insights if applicable, or null"\n}');
    buffer.writeln();

    // 2. Request Intent
    switch (request.requestType) {
      case AIRequestType.monthlySummary:
        buffer.writeln('TASK: Generate an interpretive MONTHLY SPENDING SUMMARY analyzing current spending patterns vs historical trends.');
        break;
      case AIRequestType.spendingAdvice:
        buffer.writeln('TASK: Generate actionable SPENDING ADVICE focusing on budget discipline and optimization opportunities derived from the active insights.');
        break;
    }
    buffer.writeln();

    // 3. Serialized Bounded Financial Context (Data Minimization Enforced)
    buffer.writeln('--- AUTHORITATIVE FINANCIAL CONTEXT ---');
    final dateFormat = DateFormat('yyyy-MM-dd');
    buffer.writeln('Current Period: ${dateFormat.format(context.periodStart)} to ${dateFormat.format(context.periodEnd)}');
    buffer.writeln('Current Month Total: ${CurrencyFormatter.formatPaise(context.currentMonthTotalPaise)} (${context.currentMonthExpenseCount} expenses)');
    buffer.writeln('Previous Month Total: ${CurrencyFormatter.formatPaise(context.previousMonthTotalPaise)} (${context.previousMonthExpenseCount} expenses)');

    if (context.topCategory != null) {
      buffer.writeln('Top Category: ${context.topCategory!.displayName}');
    }

    if (context.categoryTotals.isNotEmpty) {
      buffer.writeln('Category Totals:');
      for (final cat in context.categoryTotals) {
        buffer.writeln('  - ${cat.category.displayName}: ${CurrencyFormatter.formatPaise(cat.totalAmountPaise)}');
      }
    }

    if (context.largestExpense != null) {
      final exp = context.largestExpense!;
      buffer.writeln('Largest Single Expense: ${CurrencyFormatter.formatPaise(exp.amountPaise)} in ${exp.category.displayName} on ${dateFormat.format(exp.expenseDate)}');
    }

    if (context.ruleBasedInsights.hasInsights) {
      buffer.writeln('Active Rule-Based Insights:');
      for (final insight in context.ruleBasedInsights.insights) {
        buffer.writeln('  - [${insight.priority.name.toUpperCase()}] (${insight.type.name}) ${insight.title}: ${insight.description}');
      }
    }

    if (context.spendingTrends.highestSpendingDay != null) {
      final hsd = context.spendingTrends.highestSpendingDay!;
      buffer.writeln('Highest Spending Day: ${dateFormat.format(hsd.date)} (${CurrencyFormatter.formatPaise(hsd.totalAmountPaise)})');
    }

    if (context.recentExpenses.isNotEmpty) {
      buffer.writeln('Recent Expenses:');
      for (final exp in context.recentExpenses.take(5)) {
        buffer.writeln('  - ${dateFormat.format(exp.expenseDate)}: ${CurrencyFormatter.formatPaise(exp.amountPaise)} in ${exp.category.displayName}');
      }
    }
    buffer.writeln('---------------------------------------');

    return buffer.toString();
  }
}

import '../../domain/models/ai_insight.dart';
import '../../domain/models/ai_insight_request.dart';
import '../../domain/models/ai_insight_response.dart';
import '../../domain/models/ai_request_type.dart';
import '../../domain/repositories/ai_insight_provider.dart';

/// Deterministic mock implementation of [AIInsightProvider] for testing and development.
///
/// Produces reproducible, contextual insights directly derived from the supplied [AIContext]
/// without accessing external networks or LLM APIs.
class MockAIInsightProvider implements AIInsightProvider {
  const MockAIInsightProvider();

  @override
  Future<AIInsightResponse> generateInsight(AIInsightRequest request) async {
    final context = request.context;
    final generatedAt = DateTime.now();

    final AIInsight insight;

    switch (request.requestType) {
      case AIRequestType.monthlySummary:
        if (!context.hasExpenses) {
          insight = AIInsight(
            title: 'No spending recorded this month',
            explanation: 'You have not recorded any personal expenses in the current period.',
            recommendation: 'Record your expenses consistently to enable intelligent spending analysis.',
            generatedAt: generatedAt,
          );
        } else {
          final topCat = context.topCategory?.displayName;
          final count = context.currentMonthExpenseCount;
          final countText = count == 1 ? '1 expense' : '$count expenses';

          final title = topCat != null
              ? '$topCat is your primary focus this month'
              : 'Monthly spending summary';

          final explanation = topCat != null
              ? 'You recorded $countText this period, with the largest portion dedicated to $topCat.'
              : 'You recorded $countText across multiple categories during the current period.';

          final recommendation = context.ruleBasedInsights.hasInsights
              ? 'Keep an eye on ${context.ruleBasedInsights.highestPriority!.title.toLowerCase()} to stay within your targets.'
              : 'Continue tracking your daily expenses to surface deeper spending patterns over time.';

          insight = AIInsight(
            title: title,
            explanation: explanation,
            recommendation: recommendation,
            supportingInsightType: context.ruleBasedInsights.highestPriority?.type,
            generatedAt: generatedAt,
          );
        }
        break;

      case AIRequestType.spendingAdvice:
        if (!context.hasExpenses) {
          insight = AIInsight(
            title: 'No expense data available for advice',
            explanation: 'Personal expense tracking helps identify recurring spending habits.',
            recommendation: 'Start by logging your daily groceries, bills, and transit expenses.',
            generatedAt: generatedAt,
          );
        } else if (context.ruleBasedInsights.hasInsights) {
          final priority = context.ruleBasedInsights.highestPriority!;
          insight = AIInsight(
            title: 'Optimization advice: ${priority.title}',
            explanation: priority.description,
            recommendation: context.topCategory != null
                ? 'Review upcoming ${context.topCategory!.displayName} spending to balance your budget for the rest of the month.'
                : 'Review your largest expenses to identify planned savings opportunities.',
            supportingInsightType: priority.type,
            generatedAt: generatedAt,
          );
        } else {
          insight = AIInsight(
            title: 'Spending is well balanced',
            explanation: 'No concentrated spending or unusual spikes were detected in your current period.',
            recommendation: 'Maintain your current spending discipline and keep monitoring daily entries.',
            generatedAt: generatedAt,
          );
        }
        break;
    }

    return AIInsightResponse(
      insight: insight,
      providerMetadata: const {
        'provider': 'MockAIInsightProvider',
        'deterministic': 'true',
      },
    );
  }
}

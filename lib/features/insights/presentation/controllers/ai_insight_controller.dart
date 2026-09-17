import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../expense/domain/models/spending_analytics.dart';
import '../../../expense/domain/models/spending_insights.dart';
import '../../../expense/domain/models/spending_trends.dart';
import '../../domain/models/ai_insight_exception.dart';
import '../../domain/models/ai_insight_request.dart';
import '../../domain/models/ai_request_type.dart';
import '../../domain/repositories/ai_insight_repository.dart';
import '../../domain/services/ai_context_builder.dart';
import '../../domain/services/ai_response_validator.dart';
import 'ai_insight_cache.dart';
import 'ai_insight_state.dart';

/// Presentation controller orchestrating user-facing AI insight generation.
///
/// Ensures:
/// - M7 financial source of truth is preserved (zero financial mutations).
/// - Session caching prevents redundant remote requests.
/// - Concurrency guard prevents duplicate concurrent executions.
/// - Empty financial data avoids wasteful API requests.
/// - Errors are sanitized for user safety with log-safe internal classification.
class AIInsightController extends StateNotifier<AIInsightState> {
  final AIInsightRepository repository;
  final AIContextBuilder contextBuilder;
  final AIInsightCache cache;

  AIInsightController({
    required this.repository,
    this.contextBuilder = const AIContextBuilder(),
    required this.cache,
  }) : super(const AIInsightState.initial());

  /// Requests an interpretive monthly spending summary from AI.
  Future<void> requestMonthlySummary({
    required SpendingAnalytics analytics,
    required SpendingTrends trends,
    required SpendingInsights insights,
  }) async {
    await requestInsight(
      requestType: AIRequestType.monthlySummary,
      analytics: analytics,
      trends: trends,
      insights: insights,
    );
  }

  /// Requests actionable, grounded spending advice from AI.
  Future<void> requestSpendingAdvice({
    required SpendingAnalytics analytics,
    required SpendingTrends trends,
    required SpendingInsights insights,
  }) async {
    await requestInsight(
      requestType: AIRequestType.spendingAdvice,
      analytics: analytics,
      trends: trends,
      insights: insights,
    );
  }

  /// Retries the most recent request type or defaults to monthlySummary.
  Future<void> retry({
    required SpendingAnalytics analytics,
    required SpendingTrends trends,
    required SpendingInsights insights,
  }) async {
    final type = state.requestType ?? AIRequestType.monthlySummary;
    await requestInsight(
      requestType: type,
      analytics: analytics,
      trends: trends,
      insights: insights,
    );
  }

  /// Core request orchestrator with safeguards, caching, and error sanitation.
  Future<void> requestInsight({
    required AIRequestType requestType,
    required SpendingAnalytics analytics,
    required SpendingTrends trends,
    required SpendingInsights insights,
  }) async {
    // 1. Guard against empty financial data
    if (!analytics.hasCurrentMonthExpenses ||
        analytics.currentMonthExpenseCount == 0) {
      state = AIInsightState.empty(
        requestType: requestType,
        message: 'Add some expenses to generate AI spending insights.',
      );
      return;
    }

    // 2. Prevent duplicate concurrent requests
    if (state.isLoading && state.requestType == requestType) {
      return;
    }

    // 3. Build bounded financial context
    final context = contextBuilder.buildContext(
      analytics: analytics,
      trends: trends,
      insights: insights,
    );

    final request = AIInsightRequest(
      context: context,
      requestType: requestType,
    );

    // 4. Check in-memory session cache
    final cachedInsight = cache.get(request);
    if (cachedInsight != null) {
      state = AIInsightState.success(
        requestType: requestType,
        insight: cachedInsight,
      );
      return;
    }

    // 5. Transition to loading state
    state = AIInsightState.loading(
      requestType: requestType,
      previousInsight: state.insight,
    );

    // 6. Execute AI generation safely
    try {
      final response = await repository.generateInsight(request);

      // Update cache
      cache.put(request, response.insight);

      // Transition to success state
      state = AIInsightState.success(
        requestType: requestType,
        insight: response.insight,
      );
    } catch (e) {
      // 7. Classify error safely without leaking credentials, tokens, or raw payloads
      final internalClassification = _classifyError(e);

      state = AIInsightState.error(
        requestType: requestType,
        errorMessage: 'AI insights are temporarily unavailable.',
        internalErrorType: internalClassification,
        previousInsight: state.insight,
      );
    }
  }

  /// Maps domain / provider exceptions to safe classification names.
  String _classifyError(Object error) {
    if (error is AINetworkException) return 'AINetworkException';
    if (error is AITimeoutException) return 'AITimeoutException';
    if (error is AIAuthException) return 'AIAuthException';
    if (error is AIMalformedResponseException) {
      return 'AIMalformedResponseException';
    }
    if (error is AIProviderException) return 'AIProviderException';
    if (error is AIValidationException) return 'AIValidationException';
    return 'UnknownException';
  }
}

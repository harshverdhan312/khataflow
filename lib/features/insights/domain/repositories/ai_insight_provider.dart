import '../models/ai_insight_request.dart';
import '../models/ai_insight_response.dart';

/// Provider abstraction for generating AI insights from structured financial context.
///
/// Implementations (e.g. Mock in M8.1, Gemini in M8.2) must fulfill this contract.
abstract class AIInsightProvider {
  /// Generates an [AIInsightResponse] based on the supplied [request].
  Future<AIInsightResponse> generateInsight(AIInsightRequest request);
}

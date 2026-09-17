import '../models/ai_insight_request.dart';
import '../models/ai_insight_response.dart';

/// Repository boundary for requesting and retrieving AI insights.
///
/// Keeps presentation and domain clients decoupled from underlying AI provider implementations.
abstract class AIInsightRepository {
  /// Generates a validated [AIInsightResponse] from the given [request].
  Future<AIInsightResponse> generateInsight(AIInsightRequest request);
}

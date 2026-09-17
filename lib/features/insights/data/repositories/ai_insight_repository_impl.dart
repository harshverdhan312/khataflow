import '../../domain/models/ai_insight_request.dart';
import '../../domain/models/ai_insight_response.dart';
import '../../domain/repositories/ai_insight_provider.dart';
import '../../domain/repositories/ai_insight_repository.dart';
import '../../domain/services/ai_response_validator.dart';
import '../providers/mock_ai_insight_provider.dart';

/// Concrete implementation of [AIInsightRepository].
///
/// Composes an [AIInsightProvider] and enforces output correctness and safety
/// using an [AIResponseValidator] before delivering the result to consumers.
class AIInsightRepositoryImpl implements AIInsightRepository {
  final AIInsightProvider provider;
  final AIResponseValidator validator;

  const AIInsightRepositoryImpl({
    this.provider = const MockAIInsightProvider(),
    this.validator = const AIResponseValidator(),
  });

  @override
  Future<AIInsightResponse> generateInsight(AIInsightRequest request) async {
    final response = await provider.generateInsight(request);

    // Enforce safety & structural validation boundary
    validator.validate(response.insight);

    return response;
  }
}

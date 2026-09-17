import '../../domain/models/ai_insight_exception.dart';
import '../../domain/models/ai_insight_request.dart';
import '../../domain/models/ai_insight_response.dart';
import '../../domain/repositories/ai_insight_provider.dart';
import '../config/ai_provider_config.dart';
import '../network/ai_http_client.dart';
import '../parser/ai_response_parser.dart';
import '../prompt/ai_prompt_builder.dart';

/// Concrete [AIInsightProvider] connecting to real AI endpoints or secure gateway proxies.
class RealAIInsightProvider implements AIInsightProvider {
  final AIProviderConfig config;
  final AiHttpClient httpClient;
  final AiPromptBuilder promptBuilder;
  final AiResponseParser responseParser;

  const RealAIInsightProvider({
    required this.config,
    this.httpClient = const PlatformAiHttpClient(),
    this.promptBuilder = const AiPromptBuilder(),
    this.responseParser = const AiResponseParser(),
  });

  @override
  Future<AIInsightResponse> generateInsight(AIInsightRequest request) async {
    if (!config.isConfigured) {
      throw const AIAuthException(
        'AI provider is unconfigured. Provide valid gateway settings or direct API configuration.',
      );
    }

    final headers = config.buildHeaders();
    final body = promptBuilder.buildRequestPayload(request);

    final response = await httpClient.post(
      url: config.endpointUrl,
      headers: headers,
      body: body,
      timeout: config.timeout,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final insight = responseParser.parseResponse(response.body);
      return AIInsightResponse(
        insight: insight,
        providerMetadata: {
          'provider': config.modelName,
          'endpoint': config.endpointUrl.host,
        },
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AIAuthException(
        'AI provider authentication rejected (HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode == 429) {
      throw const AIProviderException(
        message: 'AI provider rate limit exceeded. Please try again later.',
        statusCode: 429,
      );
    }

    throw AIProviderException(
      message: 'AI provider returned an error response (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }
}

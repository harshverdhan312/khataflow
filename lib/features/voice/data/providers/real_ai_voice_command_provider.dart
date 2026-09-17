import 'dart:convert';

import '../../../insights/data/config/ai_provider_config.dart';
import '../../../insights/data/network/ai_http_client.dart';
import '../../../insights/domain/models/ai_insight_exception.dart';
import '../../domain/ai_voice_command_request.dart';
import '../../domain/ai_voice_command_provider.dart';
import '../prompt/ai_voice_prompt_builder.dart';

/// Real network provider implementation communicating with a secure backend/gateway or AI service.
class RealAiVoiceCommandProvider implements AiVoiceCommandProvider {
  final AIProviderConfig config;
  final AiHttpClient httpClient;
  final AiVoicePromptBuilder promptBuilder;

  const RealAiVoiceCommandProvider({
    required this.config,
    this.httpClient = const PlatformAiHttpClient(),
    this.promptBuilder = const AiVoicePromptBuilder(),
  });

  @override
  Future<String> generateSemanticResponse(AiVoiceCommandRequest request) async {
    if (!config.isConfigured) {
      throw const AIAuthException(
        'Voice AI provider is unconfigured. Provide valid gateway settings or direct configuration.',
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
      return _extractTextFromResponse(response.body);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AIAuthException(
        'Voice AI authentication rejected (HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode == 429) {
      throw const AIProviderException(
        message: 'Voice AI provider rate limit exceeded. Please try again later.',
        statusCode: 429,
      );
    }

    throw AIProviderException(
      message: 'Voice AI provider returned error response (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  /// Extracts the response text string from the HTTP body, handling both raw JSON and Gemini envelopes.
  String _extractTextFromResponse(String responseBody) {
    if (responseBody.trim().isEmpty) {
      throw const AIMalformedResponseException('Empty response received from AI provider.');
    }

    try {
      final dynamic decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        return responseBody;
      }

      // Check for Gemini envelope: candidates[0].content.parts[0].text
      if (decoded.containsKey('candidates')) {
        final candidates = decoded['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final firstCandidate = candidates.first;
          if (firstCandidate is Map<String, dynamic>) {
            final content = firstCandidate['content'];
            if (content is Map<String, dynamic>) {
              final parts = content['parts'];
              if (parts is List && parts.isNotEmpty) {
                final firstPart = parts.first;
                if (firstPart is Map<String, dynamic> && firstPart.containsKey('text')) {
                  return firstPart['text'] as String;
                }
              }
            }
          }
        }
      }

      // Direct gateway or direct JSON response
      return responseBody;
    } catch (_) {
      // If decoding fails, return raw string to be handled by strict parser
      return responseBody;
    }
  }
}

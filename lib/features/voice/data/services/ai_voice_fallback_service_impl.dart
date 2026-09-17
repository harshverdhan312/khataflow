import '../../domain/ai_voice_command_provider.dart';
import '../../domain/ai_voice_command_request.dart';
import '../../domain/ai_voice_fallback_service.dart';
import '../../domain/semantic_voice_result.dart';
import '../../domain/voice_understanding_source.dart';
import '../parser/ai_voice_response_parser.dart';
import '../providers/mock_ai_voice_command_provider.dart';

/// Concrete implementation of [AiVoiceFallbackService].
///
/// Orchestrates the AI voice fallback pipeline:
/// 1. Constructs bounded [AiVoiceCommandRequest].
/// 2. Invokes [AiVoiceCommandProvider] to obtain raw AI response text.
/// 3. Validates and converts raw text via [AiVoiceResponseParser] into [SemanticVoiceResult].
/// 4. Catches all network, timeout, auth, or provider errors, converting them into safe [SemanticVoiceUnresolved] outcomes.
class AiVoiceFallbackServiceImpl implements AiVoiceFallbackService {
  final AiVoiceCommandProvider provider;
  final AiVoiceResponseParser parser;

  const AiVoiceFallbackServiceImpl({
    this.provider = const MockAiVoiceCommandProvider(),
    this.parser = const AiVoiceResponseParser(),
  });

  @override
  Future<SemanticVoiceResult> interpret(String transcript) async {
    // 1. Guard against oversized transcript input
    if (transcript.length > AiVoiceCommandRequest.maxTranscriptLength) {
      return SemanticVoiceUnresolved(
        rawTranscript: transcript,
        failureReason: 'Voice transcript exceeds maximum allowed length of ${AiVoiceCommandRequest.maxTranscriptLength} characters.',
        source: VoiceUnderstandingSource.unresolved,
      );
    }

    // 2. Guard against empty transcript input
    if (transcript.trim().isEmpty) {
      return SemanticVoiceUnresolved(
        rawTranscript: transcript,
        failureReason: 'Spoken transcript is empty.',
        source: VoiceUnderstandingSource.unresolved,
      );
    }

    try {
      final request = AiVoiceCommandRequest(transcript: transcript.trim());

      // 3. Obtain raw untrusted response from AI provider
      final rawResponse = await provider.generateSemanticResponse(request);

      // 4. Strictly parse and validate raw response
      return parser.parse(rawResponse, rawTranscript: transcript);
    } catch (e) {
      // 5. Sanitize all network/auth/provider exceptions into safe unresolved result
      return SemanticVoiceUnresolved(
        rawTranscript: transcript,
        failureReason: 'AI voice semantic understanding is temporarily unavailable.',
        source: VoiceUnderstandingSource.unresolved,
      );
    }
  }
}

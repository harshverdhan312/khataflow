import 'ai_voice_command_request.dart';

/// Provider abstraction for generating raw AI semantic responses from voice transcripts.
///
/// Implementations (e.g. [MockAiVoiceCommandProvider], [RealAiVoiceCommandProvider])
/// return the raw, untrusted AI output string, which must always be validated by the parser.
abstract class AiVoiceCommandProvider {
  /// Generates the raw AI response text based on the supplied [request].
  Future<String> generateSemanticResponse(AiVoiceCommandRequest request);
}

import 'semantic_voice_result.dart';

/// Domain service contract for executing optional AI voice semantic fallback.
///
/// Orchestrates provider invocation and response validation to safely produce a [SemanticVoiceResult].
abstract class AiVoiceFallbackService {
  /// Interprets an uncertain or unparsed [transcript] via AI fallback.
  Future<SemanticVoiceResult> interpret(String transcript);
}

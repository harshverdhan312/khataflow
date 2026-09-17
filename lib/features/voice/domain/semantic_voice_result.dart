import 'package:flutter/foundation.dart';
import 'semantic_voice_interpretation.dart';
import 'voice_understanding_source.dart';

/// Sealed boundary abstraction representing the result of a voice command understanding attempt.
///
/// Supports distinguishing deterministic understanding from optional AI fallback and unresolved outcomes.
@immutable
sealed class SemanticVoiceResult {
  const SemanticVoiceResult();

  /// Returns `true` if the voice command was successfully understood (either deterministically or via AI).
  bool get isUnderstood => this is SemanticVoiceSuccess;

  /// Returns `true` if the voice command could not be resolved or understood.
  bool get isUnresolved => this is SemanticVoiceUnresolved;

  /// Returns the understanding source mechanism.
  VoiceUnderstandingSource get source;

  /// Convenience getter returning the [SemanticVoiceInterpretation] if understood, or `null`.
  SemanticVoiceInterpretation? get interpretationOrNull => switch (this) {
        SemanticVoiceSuccess(:final interpretation) => interpretation,
        SemanticVoiceUnresolved() => null,
      };
}

/// Represents a successfully understood voice command interpretation.
@immutable
class SemanticVoiceSuccess extends SemanticVoiceResult {
  final SemanticVoiceInterpretation interpretation;

  const SemanticVoiceSuccess(this.interpretation);

  @override
  VoiceUnderstandingSource get source => interpretation.source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVoiceSuccess &&
          runtimeType == other.runtimeType &&
          interpretation == other.interpretation;

  @override
  int get hashCode => interpretation.hashCode;

  @override
  String toString() => 'SemanticVoiceSuccess(interpretation: $interpretation)';
}

/// Represents an unresolved, unrecognized, or failed voice command interpretation attempt.
@immutable
class SemanticVoiceUnresolved extends SemanticVoiceResult {
  final String? rawTranscript;
  final String? failureReason;

  @override
  final VoiceUnderstandingSource source;

  const SemanticVoiceUnresolved({
    this.rawTranscript,
    this.failureReason,
    this.source = VoiceUnderstandingSource.unresolved,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVoiceUnresolved &&
          runtimeType == other.runtimeType &&
          rawTranscript == other.rawTranscript &&
          failureReason == other.failureReason &&
          source == other.source;

  @override
  int get hashCode => Object.hash(rawTranscript, failureReason, source);

  @override
  String toString() =>
      'SemanticVoiceUnresolved(rawTranscript: "$rawTranscript", failureReason: "$failureReason", source: $source)';
}

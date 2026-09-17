/// Represents the source or pipeline mechanism through which a voice command interpretation was derived.
enum VoiceUnderstandingSource {
  /// Confidently understood by the local deterministic rule-based parser.
  deterministic,

  /// Interpreted by the optional semantic AI fallback when deterministic rules are uncertain.
  aiFallback,

  /// Could not be resolved or understood by any available parser/fallback.
  unresolved;

  /// Returns `true` if the interpretation was produced by local deterministic parsing.
  bool get isDeterministic => this == VoiceUnderstandingSource.deterministic;

  /// Returns `true` if the interpretation was produced by the optional AI fallback.
  bool get isAiFallback => this == VoiceUnderstandingSource.aiFallback;

  /// Returns `true` if the voice command could not be resolved.
  bool get isUnresolved => this == VoiceUnderstandingSource.unresolved;
}

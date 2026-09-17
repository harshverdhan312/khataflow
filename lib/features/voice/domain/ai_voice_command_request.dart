import 'package:flutter/foundation.dart';

/// Bounded request object for AI voice semantic interpretation.
///
/// Strictly enforces privacy and data minimization: contains ONLY the raw spoken transcript.
/// It explicitly does NOT contain database IDs, ledger balances, customer data, or transaction histories.
@immutable
class AiVoiceCommandRequest {
  static const int maxTranscriptLength = 2000;

  final String transcript;

  const AiVoiceCommandRequest({
    required this.transcript,
  }) : assert(
          transcript.length <= maxTranscriptLength,
          'Transcript length exceeds maximum allowed limit of $maxTranscriptLength characters.',
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiVoiceCommandRequest &&
          runtimeType == other.runtimeType &&
          transcript == other.transcript;

  @override
  int get hashCode => transcript.hashCode;

  @override
  String toString() => 'AiVoiceCommandRequest(transcript: "$transcript")';
}

import 'package:flutter/foundation.dart';

/// Represents raw speech recognition output.
///
/// Contains only the recognized text, locale, finality status, and timestamp.
/// It explicitly does NOT contain business entities or financial interpretations.
@immutable
class VoiceTranscript {
  final String text;
  final String? locale;
  final bool isFinal;
  final DateTime capturedAt;

  const VoiceTranscript({
    required this.text,
    this.locale,
    this.isFinal = false,
    required this.capturedAt,
  });

  VoiceTranscript copyWith({
    String? text,
    String? locale,
    bool? isFinal,
    DateTime? capturedAt,
  }) {
    return VoiceTranscript(
      text: text ?? this.text,
      locale: locale ?? this.locale,
      isFinal: isFinal ?? this.isFinal,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceTranscript &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          locale == other.locale &&
          isFinal == other.isFinal &&
          capturedAt == other.capturedAt;

  @override
  int get hashCode =>
      text.hashCode ^ locale.hashCode ^ isFinal.hashCode ^ capturedAt.hashCode;

  @override
  String toString() =>
      'VoiceTranscript(text: "$text", locale: $locale, isFinal: $isFinal, capturedAt: $capturedAt)';
}

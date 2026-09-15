import 'voice_command.dart';
import 'voice_transcript.dart';

/// Sealed result of a voice command parsing operation.
sealed class VoiceParseResult {
  const VoiceParseResult();
}

/// Successful parsing result containing the structured [VoiceCommand].
class VoiceParseSuccess extends VoiceParseResult {
  final VoiceCommand command;

  const VoiceParseSuccess(this.command);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceParseSuccess &&
          runtimeType == other.runtimeType &&
          command == other.command;

  @override
  int get hashCode => command.hashCode;

  @override
  String toString() => 'VoiceParseSuccess(command: $command)';
}

/// Parsing failure containing a user-friendly error message.
class VoiceParseFailure extends VoiceParseResult {
  final String errorMessage;

  const VoiceParseFailure(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceParseFailure &&
          runtimeType == other.runtimeType &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => errorMessage.hashCode;

  @override
  String toString() => 'VoiceParseFailure(errorMessage: "$errorMessage")';
}

/// Provider-independent parser interface for converting [VoiceTranscript] into [VoiceCommand].
abstract interface class VoiceCommandParser {
  /// Parses the captured [transcript] into a [VoiceParseResult].
  VoiceParseResult parse(VoiceTranscript transcript);
}

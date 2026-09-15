import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Provider-independent speech recognition service interface.
abstract class VoiceService {
  /// Initializes the speech recognition engine and checks availability.
  Future<bool> initialize();

  /// Checks if microphone and speech recognition permissions are granted.
  Future<bool> hasPermission();

  /// Starts listening for speech input.
  ///
  /// [onResult] is invoked with incremental partial and final transcripts.
  /// [onError] is invoked when speech recognition encounters an error.
  /// [localeId] specifies the speech recognition locale (e.g. 'en_IN', 'hi_IN').
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String error) onError,
    String? localeId,
  });

  /// Stops listening and commits the final recognized speech.
  Future<void> stopListening();

  /// Cancels listening and discards any pending audio/transcripts.
  Future<void> cancelListening();

  /// Whether the microphone is currently active and listening.
  bool get isListening;

  /// Whether speech recognition is available on this device.
  bool get isAvailable;
}

/// Production implementation of [VoiceService] backed by the `speech_to_text` package.
class SpeechToTextVoiceService implements VoiceService {
  final stt.SpeechToText _speechToText;
  bool _isInitialized = false;

  SpeechToTextVoiceService({stt.SpeechToText? speechToText})
      : _speechToText = speechToText ?? stt.SpeechToText();

  @override
  bool get isListening => _speechToText.isListening;

  @override
  bool get isAvailable => _isInitialized && _speechToText.isAvailable;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return _speechToText.isAvailable;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (errorNotification) {
          debugPrint('SpeechToText error: ${errorNotification.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('SpeechToText status: $status');
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('SpeechToText initialization failed: $e');
      _isInitialized = false;
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    return _speechToText.hasPermission;
  }

  @override
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String error) onError,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError('Speech recognition is unavailable or microphone permission was denied.');
        return;
      }
    }

    try {
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  @override
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }

  @override
  Future<void> cancelListening() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/voice/domain/voice_transcript.dart';

void main() {
  group('VoiceTranscript Domain Model', () {
    final now = DateTime.now();

    test('creates valid transcript and preserves text exactly', () {
      const text = 'Sharma se doodh 60 aur bread 40 ka liya';
      final transcript = VoiceTranscript(
        text: text,
        locale: 'en_IN',
        isFinal: false,
        capturedAt: now,
      );

      expect(transcript.text, equals('Sharma se doodh 60 aur bread 40 ka liya'));
      expect(transcript.locale, equals('en_IN'));
      expect(transcript.isFinal, isFalse);
      expect(transcript.capturedAt, equals(now));
    });

    test('preserves mixed Hindi / English (Hinglish) text without alteration', () {
      const hinglishText = 'Gupta store ko 500 rupaye cash de diye';
      final transcript = VoiceTranscript(
        text: hinglishText,
        locale: 'hi_IN',
        isFinal: true,
        capturedAt: now,
      );

      expect(transcript.text, equals('Gupta store ko 500 rupaye cash de diye'));
      expect(transcript.locale, equals('hi_IN'));
      expect(transcript.isFinal, isTrue);
    });

    test('supports partial and final transcript transitions with copyWith', () {
      final partial = VoiceTranscript(
        text: 'Sharma se doodh',
        locale: 'en_IN',
        isFinal: false,
        capturedAt: now,
      );

      final finalTranscript = partial.copyWith(
        text: 'Sharma se doodh 60 aur bread 40 ka liya',
        isFinal: true,
      );

      expect(finalTranscript.text, equals('Sharma se doodh 60 aur bread 40 ka liya'));
      expect(finalTranscript.isFinal, isTrue);
      expect(finalTranscript.locale, equals('en_IN'));
      expect(finalTranscript.capturedAt, equals(now));
    });

    test('equality and hashCode verify identical transcript instances', () {
      final t1 = VoiceTranscript(
        text: 'Test transcript',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: now,
      );
      final t2 = VoiceTranscript(
        text: 'Test transcript',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: now,
      );
      final t3 = VoiceTranscript(
        text: 'Different transcript',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: now,
      );

      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));
      expect(t1, isNot(equals(t3)));
    });
  });
}

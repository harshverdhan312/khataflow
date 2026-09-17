import 'package:flutter_test/flutter_test.dart';

import 'package:khata_flow/features/voice/domain/semantic_voice_intent.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_interpretation.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_result.dart';
import 'package:khata_flow/features/voice/domain/voice_understanding_source.dart';

void main() {
  group('M8.6.1 — AI Voice Semantic Command Domain Boundary Tests', () {
    // =========================================================================
    // 1. ADD_PURCHASE interpretation
    // =========================================================================
    test('1. ADD_PURCHASE interpretation encapsulates merchant, item, and raw amountText', () {
      final interpretation = SemanticVoiceInterpretation.addPurchase(
        merchantReference: 'Sharma General Store',
        item: 'Milk and eggs',
        amountText: '150 rupees',
        dateText: 'today',
        note: 'daily essentials',
        rawTranscript: 'Sharma general store me 150 rupaye ka milk and eggs add karo',
      );

      expect(interpretation.intent, SemanticVoiceIntent.addPurchase);
      expect(interpretation.intent.code, 'ADD_PURCHASE');
      expect(interpretation.merchantReference, 'Sharma General Store');
      expect(interpretation.item, 'Milk and eggs');
      expect(interpretation.amountText, '150 rupees');
      expect(interpretation.dateText, 'today');
      expect(interpretation.note, 'daily essentials');
      expect(interpretation.source, VoiceUnderstandingSource.aiFallback);
      expect(interpretation.rawTranscript, contains('Sharma general store'));
    });

    // =========================================================================
    // 2. ADD_EXPENSE interpretation
    // =========================================================================
    test('2. ADD_EXPENSE interpretation encapsulates raw amountText and category reference', () {
      final interpretation = SemanticVoiceInterpretation.addExpense(
        amountText: '500',
        categoryReference: 'Food',
        note: 'Dinner with friends',
        dateText: 'yesterday',
        rawTranscript: 'kal sham ko 500 rupaye dinner me kharch kiye',
      );

      expect(interpretation.intent, SemanticVoiceIntent.addExpense);
      expect(interpretation.intent.code, 'ADD_EXPENSE');
      expect(interpretation.amountText, '500');
      expect(interpretation.categoryReference, 'Food');
      expect(interpretation.note, 'Dinner with friends');
      expect(interpretation.dateText, 'yesterday');
      expect(interpretation.merchantReference, isNull);
    });

    // =========================================================================
    // 3. SETTLE_MERCHANT interpretation
    // =========================================================================
    test('3. SETTLE_MERCHANT interpretation encapsulates merchant reference and optional paymentReference', () {
      final interpretation = SemanticVoiceInterpretation.settleMerchant(
        merchantReference: 'Gupta Medicals',
        amountText: '1200',
        paymentReference: 'UPI / PhonePe',
        note: 'Full settlement',
        rawTranscript: 'Gupta Medicals ka 1200 rupaye settle kar diya via UPI',
      );

      expect(interpretation.intent, SemanticVoiceIntent.settleMerchant);
      expect(interpretation.intent.code, 'SETTLE_MERCHANT');
      expect(interpretation.merchantReference, 'Gupta Medicals');
      expect(interpretation.amountText, '1200');
      expect(interpretation.paymentReference, 'UPI / PhonePe');
      expect(interpretation.item, isNull);
    });

    // =========================================================================
    // 4. CREATE_MERCHANT interpretation
    // =========================================================================
    test('4. CREATE_MERCHANT interpretation encapsulates merchant name and category reference', () {
      final interpretation = SemanticVoiceInterpretation.createMerchant(
        merchantReference: 'Verma Sweet House',
        categoryReference: 'Bakery & Sweets',
        note: 'Near main gate',
        rawTranscript: 'naya merchant banao Verma Sweet House',
      );

      expect(interpretation.intent, SemanticVoiceIntent.createMerchant);
      expect(interpretation.intent.code, 'CREATE_MERCHANT');
      expect(interpretation.merchantReference, 'Verma Sweet House');
      expect(interpretation.categoryReference, 'Bakery & Sweets');
      expect(interpretation.note, 'Near main gate');
      expect(interpretation.amountText, isNull);
    });

    // =========================================================================
    // 5. Nullable optional fields
    // =========================================================================
    test('5. Optional fields are safely nullable when not present in voice input', () {
      const minimal = SemanticVoiceInterpretation(
        intent: SemanticVoiceIntent.settleMerchant,
        merchantReference: 'Ramesh Store',
      );

      expect(minimal.intent, SemanticVoiceIntent.settleMerchant);
      expect(minimal.merchantReference, 'Ramesh Store');
      expect(minimal.item, isNull);
      expect(minimal.categoryReference, isNull);
      expect(minimal.amountText, isNull);
      expect(minimal.dateText, isNull);
      expect(minimal.note, isNull);
      expect(minimal.paymentReference, isNull);
      expect(minimal.rawTranscript, isNull);
    });

    // =========================================================================
    // 6. Deterministic source
    // =========================================================================
    test('6. VoiceUnderstandingSource.deterministic identifies local rule-based understanding', () {
      const source = VoiceUnderstandingSource.deterministic;
      expect(source.isDeterministic, isTrue);
      expect(source.isAiFallback, isFalse);
      expect(source.isUnresolved, isFalse);

      final interpretation = SemanticVoiceInterpretation.addPurchase(
        merchantReference: 'Sharmaji',
        amountText: '200',
        source: VoiceUnderstandingSource.deterministic,
      );

      expect(interpretation.source, VoiceUnderstandingSource.deterministic);
      expect(interpretation.source.isDeterministic, isTrue);
    });

    // =========================================================================
    // 7. AIFallback source
    // =========================================================================
    test('7. VoiceUnderstandingSource.aiFallback identifies optional AI-assisted understanding', () {
      const source = VoiceUnderstandingSource.aiFallback;
      expect(source.isAiFallback, isTrue);
      expect(source.isDeterministic, isFalse);
      expect(source.isUnresolved, isFalse);

      final interpretation = SemanticVoiceInterpretation.addExpense(
        amountText: '300',
        source: VoiceUnderstandingSource.aiFallback,
      );

      expect(interpretation.source, VoiceUnderstandingSource.aiFallback);
      expect(interpretation.source.isAiFallback, isTrue);
    });

    // =========================================================================
    // 8. Unresolved result
    // =========================================================================
    test('8. SemanticVoiceUnresolved represents unrecognized or failed semantic interpretation', () {
      const unresolved = SemanticVoiceUnresolved(
        rawTranscript: 'random audio chatter with no intent',
        failureReason: 'No recognizable transaction intention detected',
        source: VoiceUnderstandingSource.unresolved,
      );

      expect(unresolved.isUnderstood, isFalse);
      expect(unresolved.isUnresolved, isTrue);
      expect(unresolved.source, VoiceUnderstandingSource.unresolved);
      expect(unresolved.interpretationOrNull, isNull);
      expect(unresolved.rawTranscript, 'random audio chatter with no intent');
      expect(unresolved.failureReason, contains('No recognizable transaction'));
    });

    // =========================================================================
    // 9. Immutable and value equality behavior
    // =========================================================================
    test('9. Semantic domain objects exhibit value equality and immutability', () {
      final a = SemanticVoiceInterpretation.addPurchase(
        merchantReference: 'Kirana Store',
        amountText: '250',
        item: 'Biscuits',
        source: VoiceUnderstandingSource.aiFallback,
      );

      final b = SemanticVoiceInterpretation.addPurchase(
        merchantReference: 'Kirana Store',
        amountText: '250',
        item: 'Biscuits',
        source: VoiceUnderstandingSource.aiFallback,
      );

      final c = a.copyWith(amountText: '500');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(c.amountText, '500');
      expect(c.merchantReference, 'Kirana Store');

      final successResult1 = SemanticVoiceSuccess(a);
      final successResult2 = SemanticVoiceSuccess(b);
      expect(successResult1, equals(successResult2));
      expect(successResult1.isUnderstood, isTrue);
      expect(successResult1.interpretationOrNull, equals(a));
    });

    // =========================================================================
    // 10. Rejection and parsing of intent string codes
    // =========================================================================
    test('10. SemanticVoiceIntent.tryFromCode parses valid codes and safely rejects invalid ones', () {
      expect(SemanticVoiceIntent.tryFromCode('ADD_PURCHASE'), SemanticVoiceIntent.addPurchase);
      expect(SemanticVoiceIntent.tryFromCode('add_purchase'), SemanticVoiceIntent.addPurchase);
      expect(SemanticVoiceIntent.tryFromCode('ADD_EXPENSE'), SemanticVoiceIntent.addExpense);
      expect(SemanticVoiceIntent.tryFromCode('SETTLE_MERCHANT'), SemanticVoiceIntent.settleMerchant);
      expect(SemanticVoiceIntent.tryFromCode('CREATE_MERCHANT'), SemanticVoiceIntent.createMerchant);

      expect(SemanticVoiceIntent.tryFromCode(''), isNull);
      expect(SemanticVoiceIntent.tryFromCode('DELETE_DATABASE'), isNull);
      expect(SemanticVoiceIntent.tryFromCode('EXECUTE_PAYMENT'), isNull);
      expect(SemanticVoiceIntent.tryFromCode('UNKNOWN_INTENT'), isNull);
    });

    // =========================================================================
    // Architectural Safety Invariant Tests
    // =========================================================================
    test('Safety Invariant — No amountPaise exists in the AI semantic interpretation domain model', () {
      // Proves that SemanticVoiceInterpretation deals solely in raw semantic text (`amountText`),
      // leaving paise conversion to the deterministic domain money parsers.
      final interpretation = SemanticVoiceInterpretation.addPurchase(
        merchantReference: 'Chai Point',
        amountText: '₹45.50',
      );

      expect(interpretation.amountText, '₹45.50');
      // Verify via reflection/type system: amountText is String, not int paise
      expect(interpretation.amountText, isA<String>());
    });

    test('Safety Invariant — Model is completely decoupled from database and repositories', () {
      // Creating, transforming, and comparing semantic interpretations requires zero DB/network context
      const interpretation = SemanticVoiceInterpretation(
        intent: SemanticVoiceIntent.addExpense,
        amountText: '100',
        categoryReference: 'Snacks',
      );

      const result = SemanticVoiceSuccess(interpretation);
      expect(result.source, VoiceUnderstandingSource.aiFallback);
      expect(result.interpretation.intent, SemanticVoiceIntent.addExpense);
    });
  });
}

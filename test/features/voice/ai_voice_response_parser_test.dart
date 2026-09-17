import 'package:flutter_test/flutter_test.dart';

import 'package:khata_flow/features/voice/data/parser/ai_voice_response_parser.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_intent.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_result.dart';
import 'package:khata_flow/features/voice/domain/voice_understanding_source.dart';

void main() {
  const parser = AiVoiceResponseParser();
  const transcript = 'test transcript speech input';

  group('M8.6.2 — Structured AI Voice Response Parser Tests', () {
    // =========================================================================
    // 1–11: Valid Responses
    // =========================================================================
    test('1. ADD_PURCHASE with required and optional fields parses successfully', () {
      const json = '''
      {
        "intent": "ADD_PURCHASE",
        "merchant_reference": "Sharma General Store",
        "item": "Doodh",
        "category_reference": null,
        "amount_text": "60",
        "date_text": "today",
        "note": "morning dairy",
        "payment_reference": null
      }
      ''';

      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);
      expect(result, isA<SemanticVoiceSuccess>());

      final interpretation = (result as SemanticVoiceSuccess).interpretation;
      expect(interpretation.intent, SemanticVoiceIntent.addPurchase);
      expect(interpretation.merchantReference, 'Sharma General Store');
      expect(interpretation.item, 'Doodh');
      expect(interpretation.amountText, '60');
      expect(interpretation.dateText, 'today');
      expect(interpretation.note, 'morning dairy');
      expect(interpretation.categoryReference, isNull);
      expect(interpretation.paymentReference, isNull);
      expect(interpretation.source, VoiceUnderstandingSource.aiFallback);
      expect(interpretation.rawTranscript, transcript);
    });

    test('2. ADD_EXPENSE with category and note parses successfully', () {
      const json = '''
      {
        "intent": "ADD_EXPENSE",
        "merchant_reference": null,
        "item": null,
        "category_reference": "Food",
        "amount_text": "500",
        "date_text": "yesterday",
        "note": "dinner with friends",
        "payment_reference": null
      }
      ''';

      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);

      final interpretation = result.interpretationOrNull!;
      expect(interpretation.intent, SemanticVoiceIntent.addExpense);
      expect(interpretation.amountText, '500');
      expect(interpretation.categoryReference, 'Food');
      expect(interpretation.note, 'dinner with friends');
      expect(interpretation.dateText, 'yesterday');
      expect(interpretation.merchantReference, isNull);
    });

    test('3. SETTLE_MERCHANT without amount parses successfully (full balance settlement)', () {
      const json = '''
      {
        "intent": "SETTLE_MERCHANT",
        "merchant_reference": "Gupta Medical",
        "item": null,
        "category_reference": null,
        "amount_text": null,
        "date_text": null,
        "note": null,
        "payment_reference": null
      }
      ''';

      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);

      final interpretation = result.interpretationOrNull!;
      expect(interpretation.intent, SemanticVoiceIntent.settleMerchant);
      expect(interpretation.merchantReference, 'Gupta Medical');
      expect(interpretation.amountText, isNull);
    });

    test('4. SETTLE_MERCHANT with payment reference and amount parses successfully', () {
      const json = '''
      {
        "intent": "SETTLE_MERCHANT",
        "merchant_reference": "Gupta Medical",
        "item": null,
        "category_reference": null,
        "amount_text": "1200",
        "date_text": null,
        "note": "settled",
        "payment_reference": "UPI via PhonePe"
      }
      ''';

      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);

      final interpretation = result.interpretationOrNull!;
      expect(interpretation.intent, SemanticVoiceIntent.settleMerchant);
      expect(interpretation.merchantReference, 'Gupta Medical');
      expect(interpretation.amountText, '1200');
      expect(interpretation.paymentReference, 'UPI via PhonePe');
    });

    test('5. CREATE_MERCHANT parses merchant and optional category/payment reference', () {
      const json = '''
      {
        "intent": "CREATE_MERCHANT",
        "merchant_reference": "Verma Sweets",
        "item": null,
        "category_reference": "Bakery",
        "amount_text": null,
        "date_text": null,
        "note": "near bus stand",
        "payment_reference": "verma@upi"
      }
      ''';

      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);

      final interpretation = result.interpretationOrNull!;
      expect(interpretation.intent, SemanticVoiceIntent.createMerchant);
      expect(interpretation.merchantReference, 'Verma Sweets');
      expect(interpretation.categoryReference, 'Bakery');
      expect(interpretation.paymentReference, 'verma@upi');
      expect(interpretation.note, 'near bus stand');
    });

    test('6. Nullable optional fields resolve to null when omitted or explicit null', () {
      const json = '''
      {
        "intent": "ADD_EXPENSE",
        "amount_text": "250"
      }
      ''';

      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);

      final interpretation = result.interpretationOrNull!;
      expect(interpretation.amountText, '250');
      expect(interpretation.categoryReference, isNull);
      expect(interpretation.dateText, isNull);
      expect(interpretation.note, isNull);
    });

    test('7. Whitespace is safely trimmed from semantic string fields', () {
      const json = '''
      {
        "intent": " ADD_PURCHASE ",
        "merchant_reference": "  Sharma Store  ",
        "item": "  Bread  ",
        "amount_text": "  40  "
      }
      ''';

      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);

      final interpretation = result.interpretationOrNull!;
      expect(interpretation.intent, SemanticVoiceIntent.addPurchase);
      expect(interpretation.merchantReference, 'Sharma Store');
      expect(interpretation.item, 'Bread');
      expect(interpretation.amountText, '40');
    });

    test('8. Empty-after-trimming strings become null', () {
      const json = '''
      {
        "intent": "ADD_EXPENSE",
        "amount_text": "100",
        "category_reference": "   ",
        "note": ""
      }
      ''';

      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);

      final interpretation = result.interpretationOrNull!;
      expect(interpretation.categoryReference, isNull);
      expect(interpretation.note, isNull);
    });

    test('9. Markdown code fences (```json ... ```) are safely stripped', () {
      const jsonWithFence = '''
```json
{
  "intent": "ADD_PURCHASE",
  "merchant_reference": "Supermarket",
  "item": "Milk",
  "amount_text": "50"
}
```''';

      final result = parser.parse(jsonWithFence, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);
      expect(result.interpretationOrNull?.merchantReference, 'Supermarket');
    });

    test('10. Raw transcript parameter is preserved identically in domain result', () {
      const explicitTranscript = 'Sharmaji ko do packet doodh ke saath 60 rupaye do';
      const json = '''
      {
        "intent": "ADD_PURCHASE",
        "merchant_reference": "Sharmaji",
        "item": "Doodh",
        "amount_text": "60"
      }
      ''';

      final result = parser.parse(json, rawTranscript: explicitTranscript);
      expect(result.interpretationOrNull?.rawTranscript, explicitTranscript);
    });

    test('11. Source is guaranteed to be VoiceUnderstandingSource.aiFallback regardless of input', () {
      const json = '''
      {
        "intent": "ADD_EXPENSE",
        "amount_text": "100",
        "source": "deterministic"
      }
      ''';

      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);
      expect(result.source, VoiceUnderstandingSource.aiFallback);
      expect(result.interpretationOrNull?.source, VoiceUnderstandingSource.aiFallback);
    });

    // =========================================================================
    // 12–18: Invalid JSON / Schema Rejections
    // =========================================================================
    test('12. Empty string response is safely rejected as unresolved', () {
      final result = parser.parse('', rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
      expect(result, isA<SemanticVoiceUnresolved>());
    });

    test('13. Whitespace-only response is safely rejected as unresolved', () {
      final result = parser.parse('   \n\t  ', rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('14. Malformed JSON syntax is safely rejected as unresolved', () {
      final result = parser.parse('{intent: "ADD_PURCHASE", broken}', rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('15. JSON array is rejected as unresolved', () {
      final result = parser.parse('[{"intent": "ADD_PURCHASE"}]', rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('16. JSON primitive value is rejected as unresolved', () {
      final result = parser.parse('"ADD_PURCHASE"', rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('17. JSON object missing "intent" field is rejected as unresolved', () {
      const json = '{"merchant_reference": "Sharma", "amount_text": "100"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('18. Unknown intent code is rejected as unresolved without guessing', () {
      const json = '{"intent": "TRANSFER_MONEY", "amount_text": "100"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    // =========================================================================
    // 19–23: Type Safety & Non-String Rejections
    // =========================================================================
    test('19. Numeric amount_text is rejected (must be raw string)', () {
      const json = '''
      {
        "intent": "ADD_EXPENSE",
        "amount_text": 60
      }
      ''';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('20. Numeric merchant_reference is rejected (must be string)', () {
      const json = '''
      {
        "intent": "ADD_PURCHASE",
        "merchant_reference": 12345,
        "item": "Bread",
        "amount_text": "40"
      }
      ''';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('21. Array value in semantic field is rejected', () {
      const json = '''
      {
        "intent": "ADD_EXPENSE",
        "amount_text": "100",
        "category_reference": ["Food", "Groceries"]
      }
      ''';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('22. Boolean value in semantic field is rejected', () {
      const json = '''
      {
        "intent": "ADD_EXPENSE",
        "amount_text": "100",
        "note": true
      }
      ''';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('23. Null intent field is rejected', () {
      const json = '{"intent": null, "amount_text": "100"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    // =========================================================================
    // 24–29: Missing Required Fields per Intent
    // =========================================================================
    test('24. ADD_PURCHASE without merchant_reference is rejected', () {
      const json = '{"intent": "ADD_PURCHASE", "item": "Milk", "amount_text": "60"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('25. ADD_PURCHASE without item is rejected', () {
      const json = '{"intent": "ADD_PURCHASE", "merchant_reference": "Sharma", "amount_text": "60"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('26. ADD_PURCHASE without amount_text is rejected', () {
      const json = '{"intent": "ADD_PURCHASE", "merchant_reference": "Sharma", "item": "Milk"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('27. ADD_EXPENSE without amount_text is rejected', () {
      const json = '{"intent": "ADD_EXPENSE", "category_reference": "Food"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('28. SETTLE_MERCHANT without merchant_reference is rejected', () {
      const json = '{"intent": "SETTLE_MERCHANT", "amount_text": "500"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('29. CREATE_MERCHANT without merchant_reference is rejected', () {
      const json = '{"intent": "CREATE_MERCHANT", "category_reference": "Bakery"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    // =========================================================================
    // 30–33: Irrelevant Non-Null Fields per Intent
    // =========================================================================
    test('30. ADD_PURCHASE with payment_reference is rejected as irrelevant field', () {
      const json = '''
      {
        "intent": "ADD_PURCHASE",
        "merchant_reference": "Store",
        "item": "Milk",
        "amount_text": "60",
        "payment_reference": "cash"
      }
      ''';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('31. ADD_EXPENSE with merchant_reference is rejected as irrelevant field', () {
      const json = '''
      {
        "intent": "ADD_EXPENSE",
        "merchant_reference": "Store",
        "amount_text": "100"
      }
      ''';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('32. SETTLE_MERCHANT with item is rejected as irrelevant field', () {
      const json = '''
      {
        "intent": "SETTLE_MERCHANT",
        "merchant_reference": "Store",
        "item": "Soap"
      }
      ''';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('33. CREATE_MERCHANT with amount_text is rejected as irrelevant field', () {
      const json = '''
      {
        "intent": "CREATE_MERCHANT",
        "merchant_reference": "Store",
        "amount_text": "500"
      }
      ''';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    // =========================================================================
    // 34–39: String Length Bounds
    // =========================================================================
    test('34. Oversized merchant_reference (> 120 chars) is rejected', () {
      final json = '{"intent": "CREATE_MERCHANT", "merchant_reference": "${'A' * 121}"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('35. Oversized item (> 200 chars) is rejected', () {
      final json = '{"intent": "ADD_PURCHASE", "merchant_reference": "Store", "item": "${'A' * 201}", "amount_text": "50"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('36. Oversized amount_text (> 100 chars) is rejected', () {
      final json = '{"intent": "ADD_EXPENSE", "amount_text": "${'1' * 101}"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('37. Oversized note (> 200 chars) is rejected', () {
      final json = '{"intent": "ADD_EXPENSE", "amount_text": "50", "note": "${'N' * 201}"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('38. Oversized payment_reference (> 120 chars) is rejected', () {
      final json = '{"intent": "CREATE_MERCHANT", "merchant_reference": "Store", "payment_reference": "${'U' * 121}"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('39. Oversized raw transcript (> 2000 chars) is rejected', () {
      const json = '{"intent": "ADD_EXPENSE", "amount_text": "50"}';
      final result = parser.parse(json, rawTranscript: 'T' * 2001);
      expect(result.isUnresolved, isTrue);
    });

    // =========================================================================
    // 40–42: Financial Safety & Non-Conversion
    // =========================================================================
    test('40. "amount_text": "do sau pachaas" remains exactly semantic text without conversion', () {
      const json = '{"intent": "ADD_EXPENSE", "amount_text": "do sau pachaas"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);
      expect(result.interpretationOrNull?.amountText, 'do sau pachaas');
    });

    test('41. Parser produces purely SemanticVoiceInterpretation with no amountPaise', () {
      const json = '{"intent": "ADD_EXPENSE", "amount_text": "500"}';
      final result = parser.parse(json, rawTranscript: transcript);
      final interpretation = result.interpretationOrNull!;
      expect(interpretation.amountText, '500');
      expect(interpretation.amountText, isA<String>());
    });

    test('42. No numeric financial conversion or arithmetic is performed by the parser', () {
      const json = '{"intent": "ADD_PURCHASE", "merchant_reference": "Shop", "item": "Biscuits", "amount_text": "₹150.75"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.interpretationOrNull?.amountText, '₹150.75');
    });

    // =========================================================================
    // 43–45: Date & Category Safety
    // =========================================================================
    test('43. date_text remains raw semantic text without parsing into DateTime', () {
      const json = '{"intent": "ADD_EXPENSE", "amount_text": "50", "date_text": "next monday evening"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.interpretationOrNull?.dateText, 'next monday evening');
    });

    test('44. category_reference remains raw semantic text string', () {
      const json = '{"intent": "ADD_EXPENSE", "amount_text": "50", "category_reference": "Grocery and kitchen supplies"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.interpretationOrNull?.categoryReference, 'Grocery and kitchen supplies');
    });

    test('45. No automatic category mapping occurs in the response parser', () {
      const json = '{"intent": "CREATE_MERCHANT", "merchant_reference": "Medical Shop", "category_reference": "Custom Pharmacy"}';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.interpretationOrNull?.categoryReference, 'Custom Pharmacy');
    });

    // =========================================================================
    // 46–49: Security & Robustness
    // =========================================================================
    test('46. Arbitrary unknown JSON fields are ignored and do not enter the domain model', () {
      const json = '''
      {
        "intent": "ADD_EXPENSE",
        "amount_text": "100",
        "admin_override": true,
        "database_id": "999",
        "custom_payload": {"nested": "data"}
      }
      ''';
      final result = parser.parse(json, rawTranscript: transcript);
      expect(result.isUnderstood, isTrue);
      expect(result.interpretationOrNull?.intent, SemanticVoiceIntent.addExpense);
      expect(result.interpretationOrNull?.amountText, '100');
    });

    test('47. Prose surrounding the JSON object is rejected as invalid format', () {
      const proseJson = 'Here is the JSON you requested: {"intent": "ADD_EXPENSE", "amount_text": "50"} Hope this helps!';
      final result = parser.parse(proseJson, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('48. Malformed code fence structure is rejected', () {
      const malformedFence = '```json {"intent": "ADD_EXPENSE", "amount_text": "50"}';
      final result = parser.parse(malformedFence, rawTranscript: transcript);
      expect(result.isUnresolved, isTrue);
    });

    test('49. Raw AI response payload is not leaked into failure reason', () {
      const invalidJson = '{"intent": "UNKNOWN_ACTION", "secret_token": "secret123"}';
      final result = parser.parse(invalidJson, rawTranscript: transcript);
      expect(result, isA<SemanticVoiceUnresolved>());
      final unresolved = result as SemanticVoiceUnresolved;
      expect(unresolved.failureReason, isNotNull);
      expect(unresolved.failureReason, isNot(contains('secret123')));
    });
  });
}

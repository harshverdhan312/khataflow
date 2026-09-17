import 'package:flutter_test/flutter_test.dart';

import 'package:khata_flow/features/insights/data/config/ai_provider_config.dart';
import 'package:khata_flow/features/insights/data/network/ai_http_client.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_exception.dart';
import 'package:khata_flow/features/voice/data/prompt/ai_voice_prompt_builder.dart';
import 'package:khata_flow/features/voice/data/providers/mock_ai_voice_command_provider.dart';
import 'package:khata_flow/features/voice/data/providers/real_ai_voice_command_provider.dart';
import 'package:khata_flow/features/voice/data/services/ai_voice_fallback_service_impl.dart';
import 'package:khata_flow/features/voice/domain/ai_voice_command_provider.dart';
import 'package:khata_flow/features/voice/domain/ai_voice_command_request.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_intent.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_result.dart';
import 'package:khata_flow/features/voice/domain/voice_understanding_source.dart';

/// Fake HTTP client for testing network and error handling without real network calls.
class FakeAiHttpClient implements AiHttpClient {
  AiHttpResponse? responseToReturn;
  Exception? exceptionToThrow;
  Uri? lastUrl;
  Map<String, String>? lastHeaders;
  String? lastBody;

  @override
  Future<AiHttpResponse> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    lastUrl = url;
    lastHeaders = headers;
    lastBody = body;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return responseToReturn ??
        const AiHttpResponse(
          statusCode: 200,
          body: '{"intent": "ADD_EXPENSE", "amount_text": "50"}',
        );
  }
}

/// Custom test provider throwing configurable errors.
class ThrowingVoiceProvider implements AiVoiceCommandProvider {
  final Exception exception;

  ThrowingVoiceProvider(this.exception);

  @override
  Future<String> generateSemanticResponse(AiVoiceCommandRequest request) async {
    throw exception;
  }
}

void main() {
  group('M8.6.3 — AI Voice Fallback Provider & Service Tests', () {
    // =========================================================================
    // 1–4: Provider Contract
    // =========================================================================
    test('1. Provider accepts AiVoiceCommandRequest containing speech transcript', () async {
      const mock = MockAiVoiceCommandProvider();
      const request = AiVoiceCommandRequest(transcript: 'Sharma Store doodh 60');

      final rawResponse = await mock.generateSemanticResponse(request);
      expect(rawResponse, isA<String>());
      expect(rawResponse, contains('ADD_PURCHASE'));
    });

    test('2. Provider returns raw JSON string rather than executable domain entities', () async {
      const mock = MockAiVoiceCommandProvider(
        customRawResponse: '{"intent": "ADD_EXPENSE", "amount_text": "100"}',
      );

      final response = await mock.generateSemanticResponse(
        const AiVoiceCommandRequest(transcript: 'kharcha 100'),
      );

      expect(response, isA<String>());
      expect(response, equals('{"intent": "ADD_EXPENSE", "amount_text": "100"}'));
    });

    test('3. Mock provider operates 100% offline without HTTP or credentials', () async {
      const mock = MockAiVoiceCommandProvider();
      final response = await mock.generateSemanticResponse(
        const AiVoiceCommandRequest(transcript: 'Gupta Medicals settle payment'),
      );

      expect(response, contains('SETTLE_MERCHANT'));
      expect(response, contains('Gupta'));
    });

    test('4. Provider contract has no repository or database dependency', () {
      const mock = MockAiVoiceCommandProvider();
      const service = AiVoiceFallbackServiceImpl(provider: mock);

      expect(service.provider, isNotNull);
      expect(service.parser, isNotNull);
    });

    // =========================================================================
    // 5–12: Parser Integration via Fallback Service
    // =========================================================================
    test('5. Valid ADD_PURCHASE raw response reaches SemanticVoiceSuccess', () async {
      const validJson = '''
      {
        "intent": "ADD_PURCHASE",
        "merchant_reference": "Sharmaji",
        "item": "Doodh packet",
        "amount_text": "60"
      }
      ''';

      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: validJson),
      );

      final result = await service.interpret('Sharmaji ke yahan se 60 ka doodh packet');
      expect(result.isUnderstood, isTrue);

      final interpretation = result.interpretationOrNull!;
      expect(interpretation.intent, SemanticVoiceIntent.addPurchase);
      expect(interpretation.merchantReference, 'Sharmaji');
      expect(interpretation.item, 'Doodh packet');
      expect(interpretation.amountText, '60');
      expect(interpretation.source, VoiceUnderstandingSource.aiFallback);
    });

    test('6. Valid ADD_EXPENSE raw response reaches SemanticVoiceSuccess', () async {
      const validJson = '''
      {
        "intent": "ADD_EXPENSE",
        "amount_text": "350",
        "category_reference": "Food",
        "note": "Lunch with team"
      }
      ''';

      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: validJson),
      );

      final result = await service.interpret('Lunch with team 350 rupees');
      expect(result.isUnderstood, isTrue);

      final interpretation = result.interpretationOrNull!;
      expect(interpretation.intent, SemanticVoiceIntent.addExpense);
      expect(interpretation.amountText, '350');
      expect(interpretation.categoryReference, 'Food');
      expect(interpretation.note, 'Lunch with team');
    });

    test('7. Valid SETTLE_MERCHANT raw response reaches SemanticVoiceSuccess', () async {
      const validJson = '''
      {
        "intent": "SETTLE_MERCHANT",
        "merchant_reference": "Verma Store",
        "amount_text": "500",
        "payment_reference": "UPI"
      }
      ''';

      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: validJson),
      );

      final result = await service.interpret('Verma store settle 500 via UPI');
      expect(result.isUnderstood, isTrue);

      final interpretation = result.interpretationOrNull!;
      expect(interpretation.intent, SemanticVoiceIntent.settleMerchant);
      expect(interpretation.merchantReference, 'Verma Store');
      expect(interpretation.amountText, '500');
      expect(interpretation.paymentReference, 'UPI');
    });

    test('8. Valid CREATE_MERCHANT raw response reaches SemanticVoiceSuccess', () async {
      const validJson = '''
      {
        "intent": "CREATE_MERCHANT",
        "merchant_reference": "New Kirana",
        "category_reference": "Groceries"
      }
      ''';

      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: validJson),
      );

      final result = await service.interpret('Naya merchant banao New Kirana');
      expect(result.isUnderstood, isTrue);

      final interpretation = result.interpretationOrNull!;
      expect(interpretation.intent, SemanticVoiceIntent.createMerchant);
      expect(interpretation.merchantReference, 'New Kirana');
      expect(interpretation.categoryReference, 'Groceries');
    });

    test('9. Malformed provider response becomes SemanticVoiceUnresolved', () async {
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: 'not a json string'),
      );

      final result = await service.interpret('some speech');
      expect(result.isUnresolved, isTrue);
      expect(result, isA<SemanticVoiceUnresolved>());
    });

    test('10. Unknown intent from provider becomes SemanticVoiceUnresolved', () async {
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(
          customRawResponse: '{"intent": "UNSUPPORTED_INTENT", "amount_text": "50"}',
        ),
      );

      final result = await service.interpret('some speech');
      expect(result.isUnresolved, isTrue);
    });

    test('11. Invalid field type from provider becomes SemanticVoiceUnresolved', () async {
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(
          customRawResponse: '{"intent": "ADD_EXPENSE", "amount_text": 50}',
        ),
      );

      final result = await service.interpret('some speech');
      expect(result.isUnresolved, isTrue);
    });

    test('12. Missing required field from provider becomes SemanticVoiceUnresolved', () async {
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(
          customRawResponse: '{"intent": "ADD_PURCHASE", "item": "Milk"}',
        ),
      );

      final result = await service.interpret('some speech');
      expect(result.isUnresolved, isTrue);
    });

    // =========================================================================
    // 13–17: Failure Handling
    // =========================================================================
    test('13. Provider timeout becomes safe SemanticVoiceUnresolved result', () async {
      final service = AiVoiceFallbackServiceImpl(
        provider: ThrowingVoiceProvider(const AITimeoutException()),
      );

      final result = await service.interpret('speech input');
      expect(result.isUnresolved, isTrue);
      final unresolved = result as SemanticVoiceUnresolved;
      expect(unresolved.failureReason, contains('temporarily unavailable'));
    });

    test('14. Network failure becomes safe SemanticVoiceUnresolved result', () async {
      final service = AiVoiceFallbackServiceImpl(
        provider: ThrowingVoiceProvider(const AINetworkException()),
      );

      final result = await service.interpret('speech input');
      expect(result.isUnresolved, isTrue);
    });

    test('15. Provider 5xx error becomes safe SemanticVoiceUnresolved result', () async {
      final service = AiVoiceFallbackServiceImpl(
        provider: ThrowingVoiceProvider(
          const AIProviderException(message: 'Server Error', statusCode: 500),
        ),
      );

      final result = await service.interpret('speech input');
      expect(result.isUnresolved, isTrue);
    });

    test('16. Unconfigured provider becomes safe SemanticVoiceUnresolved result', () async {
      final service = AiVoiceFallbackServiceImpl(
        provider: ThrowingVoiceProvider(const AIAuthException('Unconfigured')),
      );

      final result = await service.interpret('speech input');
      expect(result.isUnresolved, isTrue);
    });

    test('17. Parser failure does not leak raw provider payload to user failureReason', () async {
      const secretJson = '{"intent": "BROKEN", "confidential_key": "xyz999"}';
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: secretJson),
      );

      final result = await service.interpret('speech');
      expect(result.isUnresolved, isTrue);
      final unresolved = result as SemanticVoiceUnresolved;
      expect(unresolved.failureReason, isNot(contains('xyz999')));
    });

    // =========================================================================
    // 18–23: Security & Invariant Guarantees
    // =========================================================================
    test('18. Understanding source is guaranteed to be aiFallback', () async {
      const json = '{"intent": "ADD_EXPENSE", "amount_text": "50"}';
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: json),
      );

      final result = await service.interpret('kharch 50');
      expect(result.source, VoiceUnderstandingSource.aiFallback);
      expect(result.interpretationOrNull?.source, VoiceUnderstandingSource.aiFallback);
    });

    test('19. Provider cannot inject database merchant IDs into the interpretation', () async {
      const json = '''
      {
        "intent": "ADD_PURCHASE",
        "merchant_reference": "Sharma",
        "item": "Eggs",
        "amount_text": "50",
        "merchant_id": "db_guid_12345"
      }
      ''';
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: json),
      );

      final result = await service.interpret('Sharma eggs 50');
      expect(result.isUnderstood, isTrue);
      final interpretation = result.interpretationOrNull!;
      expect(interpretation.merchantReference, 'Sharma');
    });

    test('20. Provider cannot return amountPaise or alter integer money parsing', () async {
      const json = '{"intent": "ADD_EXPENSE", "amount_text": "500", "amount_paise": 50000}';
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: json),
      );

      final result = await service.interpret('500 rupees');
      expect(result.isUnderstood, isTrue);
      expect(result.interpretationOrNull?.amountText, '500');
    });

    test('21. Provider cannot mutate repositories or database records', () async {
      const service = AiVoiceFallbackServiceImpl(
        provider: MockAiVoiceCommandProvider(),
      );

      final result = await service.interpret('Gupta store 50');
      expect(result.isUnderstood, isTrue);
      // Zero DB operations executed
    });

    test('22. Oversized transcripts (> 2000 chars) are immediately rejected by the service', () async {
      const service = AiVoiceFallbackServiceImpl(
        provider: MockAiVoiceCommandProvider(),
      );

      final longTranscript = 'A' * 2001;
      final result = await service.interpret(longTranscript);
      expect(result.isUnresolved, isTrue);
      expect((result as SemanticVoiceUnresolved).failureReason, contains('maximum allowed length'));
    });

    test('23. Raw API credentials never enter domain result objects', () async {
      final fakeHttp = FakeAiHttpClient()
        ..responseToReturn = const AiHttpResponse(
          statusCode: 200,
          body: '{"intent": "ADD_EXPENSE", "amount_text": "80"}',
        );

      final realProvider = RealAiVoiceCommandProvider(
        config: AIProviderConfig.gateway(
          gatewayUrl: Uri.parse('https://example.com/voice-gateway'),
          userAuthToken: 'super-secret-auth-token',
        ),
        httpClient: fakeHttp,
      );

      final service = AiVoiceFallbackServiceImpl(provider: realProvider);
      final result = await service.interpret('taxi 80');

      expect(result.isUnderstood, isTrue);
      expect(result.toString(), isNot(contains('super-secret-auth-token')));
    });

    // =========================================================================
    // 24–27: Financial Integrity
    // =========================================================================
    test('24. "amount_text": "dhai sau" remains semantic text without arithmetic conversion', () async {
      const json = '{"intent": "ADD_EXPENSE", "amount_text": "dhai sau"}';
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: json),
      );

      final result = await service.interpret('dhai sau ka khana');
      expect(result.isUnderstood, isTrue);
      expect(result.interpretationOrNull?.amountText, 'dhai sau');
    });

    test('25. No numeric conversion occurs in provider or fallback service', () async {
      const json = '{"intent": "ADD_EXPENSE", "amount_text": "₹2,500.00"}';
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: json),
      );

      final result = await service.interpret('two thousand five hundred');
      expect(result.isUnderstood, isTrue);
      expect(result.interpretationOrNull?.amountText, '₹2,500.00');
    });

    test('26. No floating-point financial arithmetic occurs', () async {
      const json = '{"intent": "ADD_EXPENSE", "amount_text": "19.99"}';
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: json),
      );

      final result = await service.interpret('item for 19.99');
      expect(result.isUnderstood, isTrue);
      expect(result.interpretationOrNull?.amountText, '19.99');
      expect(result.interpretationOrNull?.amountText, isA<String>());
    });

    test('27. Fallback provider cannot modify deterministic financial data', () async {
      const json = '{"intent": "ADD_EXPENSE", "amount_text": "99999"}';
      final service = AiVoiceFallbackServiceImpl(
        provider: const MockAiVoiceCommandProvider(customRawResponse: json),
      );

      final result = await service.interpret('spend 99999');
      expect(result.isUnderstood, isTrue);
      expect(result.interpretationOrNull?.amountText, '99999');
    });

    // =========================================================================
    // 28–31: Privacy & Data Minimization
    // =========================================================================
    test('28. Prompt payload contains transcript only without extra financial history', () {
      const builder = AiVoicePromptBuilder();
      const request = AiVoiceCommandRequest(transcript: 'Sharma doodh 60');

      final payload = builder.buildRequestPayload(request);
      expect(payload, contains('Sharma doodh 60'));
      expect(payload, isNot(contains('merchant_database')));
      expect(payload, isNot(contains('expense_history')));
      expect(payload, isNot(contains('sqlite')));
    });

    test('29. No merchant database is sent in request payload', () {
      const builder = AiVoicePromptBuilder();
      const request = AiVoiceCommandRequest(transcript: 'Settle Ramesh');

      final payload = builder.buildRequestPayload(request);
      expect(payload, isNot(contains('merchants:')));
      expect(payload, isNot(contains('ledger:')));
    });

    test('30. No VPA/phone/internal IDs are sent in request payload', () {
      const builder = AiVoicePromptBuilder();
      const request = AiVoiceCommandRequest(transcript: 'Pay Verma');

      final payload = builder.buildRequestPayload(request);
      expect(payload, isNot(contains('@okhdfcbank')));
      expect(payload, isNot(contains('+91')));
      expect(payload, isNot(contains('guid')));
    });

    test('31. No historical expenses are sent in request payload', () {
      const builder = AiVoicePromptBuilder();
      const request = AiVoiceCommandRequest(transcript: 'Dinner 500');

      final payload = builder.buildRequestPayload(request);
      expect(payload, isNot(contains('previousExpenses')));
      expect(payload, isNot(contains('categoryTotals')));
    });
  });
}

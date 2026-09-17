import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/models/insight_type.dart';
import 'package:khata_flow/features/expense/domain/models/spending_insights.dart';
import 'package:khata_flow/features/expense/domain/models/spending_trends.dart';
import 'package:khata_flow/features/insights/data/config/ai_provider_config.dart';
import 'package:khata_flow/features/insights/data/network/ai_http_client.dart';
import 'package:khata_flow/features/insights/data/providers/real_ai_insight_provider.dart';
import 'package:khata_flow/features/insights/domain/models/ai_context.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_exception.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_request.dart';
import 'package:khata_flow/features/insights/domain/models/ai_request_type.dart';

class MockHttpClient implements AiHttpClient {
  final Future<AiHttpResponse> Function(Uri url, Map<String, String> headers, String body) handler;

  MockHttpClient(this.handler);

  @override
  Future<AiHttpResponse> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return handler(url, headers, body);
  }
}

void main() {
  group('RealAIInsightProvider Tests', () {
    final validContext = AIContext(
      periodStart: DateTime(2026, 9, 1),
      periodEnd: DateTime(2026, 10, 1),
      currentMonthTotalPaise: 500000,
      previousMonthTotalPaise: 400000,
      currentMonthExpenseCount: 8,
      previousMonthExpenseCount: 6,
      categoryTotals: const [],
      recentExpenses: const [],
      ruleBasedInsights: const SpendingInsights(insights: []),
      spendingTrends: const SpendingTrends(
        dailySpending: [],
        weeklySpending: [],
        monthlySpending: [],
        categoryTrends: [],
      ),
    );

    final validRequest = AIInsightRequest(
      context: validContext,
      requestType: AIRequestType.monthlySummary,
    );

    test('successful 200 response returns parsed AIInsightResponse', () async {
      final mockHttp = MockHttpClient((url, headers, body) async {
        expect(headers['Content-Type'], contains('application/json'));
        expect(headers['Authorization'], 'Bearer test_jwt_token');

        return const AiHttpResponse(
          statusCode: 200,
          body: '''
          {
            "title": "Healthy Spending Trend",
            "explanation": "You maintained a consistent spending rate throughout September.",
            "recommendation": "Continue setting aside discretionary savings.",
            "supportingInsightType": "spendingDecrease"
          }
          ''',
        );
      });

      final config = AIProviderConfig.gateway(
        gatewayUrl: Uri.parse('https://gateway.khataflow.app/api/v1/insights'),
        userAuthToken: 'test_jwt_token',
      );

      final provider = RealAIInsightProvider(
        config: config,
        httpClient: mockHttp,
      );

      final response = await provider.generateInsight(validRequest);

      expect(response.insight.title, 'Healthy Spending Trend');
      expect(response.insight.supportingInsightType, InsightType.spendingDecrease);
      expect(response.providerMetadata?['provider'], 'gemini-1.5-flash');
      expect(response.providerMetadata?['endpoint'], 'gateway.khataflow.app');
    });

    test('unconfigured provider throws AIAuthException before making network request', () async {
      final provider = RealAIInsightProvider(
        config: AIProviderConfig.disabled(),
        httpClient: MockHttpClient((url, headers, body) async => throw UnimplementedError()),
      );

      expect(
        () => provider.generateInsight(validRequest),
        throwsA(isA<AIAuthException>()),
      );
    });

    test('HTTP 401/403 status code throws AIAuthException without leaking token', () async {
      final mockHttp = MockHttpClient((url, headers, body) async {
        return const AiHttpResponse(
          statusCode: 401,
          body: '{"error": "Unauthorized access"}',
        );
      });

      final config = AIProviderConfig.gateway(
        gatewayUrl: Uri.parse('https://api.khataflow.app/ai'),
        userAuthToken: 'secret_token_12345',
      );

      final provider = RealAIInsightProvider(
        config: config,
        httpClient: mockHttp,
      );

      try {
        await provider.generateInsight(validRequest);
        fail('Should throw AIAuthException');
      } on AIAuthException catch (e) {
        expect(e.message.contains('secret_token_12345'), isFalse);
        expect(e.message, contains('401'));
      }
    });

    test('HTTP 429 status code throws rate-limit AIProviderException', () async {
      final mockHttp = MockHttpClient((url, headers, body) async {
        return const AiHttpResponse(
          statusCode: 429,
          body: '{"error": "Rate limit exceeded"}',
        );
      });

      final config = AIProviderConfig.gateway(
        gatewayUrl: Uri.parse('https://api.khataflow.app/ai'),
      );

      final provider = RealAIInsightProvider(
        config: config,
        httpClient: mockHttp,
      );

      expect(
        () => provider.generateInsight(validRequest),
        throwsA(isA<AIProviderException>().having((e) => e.statusCode, 'statusCode', 429)),
      );
    });

    test('HTTP 500 status code throws AIProviderException', () async {
      final mockHttp = MockHttpClient((url, headers, body) async {
        return const AiHttpResponse(
          statusCode: 500,
          body: '{"error": "Internal server error"}',
        );
      });

      final config = AIProviderConfig.gateway(
        gatewayUrl: Uri.parse('https://api.khataflow.app/ai'),
      );

      final provider = RealAIInsightProvider(
        config: config,
        httpClient: mockHttp,
      );

      expect(
        () => provider.generateInsight(validRequest),
        throwsA(isA<AIProviderException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('network transport failure throws AINetworkException', () async {
      final mockHttp = MockHttpClient((url, headers, body) async {
        throw const AINetworkException('DNS resolution failed');
      });

      final config = AIProviderConfig.gateway(
        gatewayUrl: Uri.parse('https://api.khataflow.app/ai'),
      );

      final provider = RealAIInsightProvider(
        config: config,
        httpClient: mockHttp,
      );

      expect(
        () => provider.generateInsight(validRequest),
        throwsA(isA<AINetworkException>()),
      );
    });

    test('network timeout throws AITimeoutException', () async {
      final mockHttp = MockHttpClient((url, headers, body) async {
        throw const AITimeoutException();
      });

      final config = AIProviderConfig.gateway(
        gatewayUrl: Uri.parse('https://api.khataflow.app/ai'),
      );

      final provider = RealAIInsightProvider(
        config: config,
        httpClient: mockHttp,
      );

      expect(
        () => provider.generateInsight(validRequest),
        throwsA(isA<AITimeoutException>()),
      );
    });
  });
}

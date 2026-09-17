import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/models/insight_type.dart';
import 'package:khata_flow/features/insights/data/parser/ai_response_parser.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight_exception.dart';

void main() {
  group('AiResponseParser Tests', () {
    const parser = AiResponseParser();

    test('parseResponse successfully parses direct JSON payload', () {
      const rawJson = '''
      {
        "title": "Food dominates your monthly budget",
        "explanation": "You spent ₹4,500 across 12 food expenses, accounting for 60% of total outlay.",
        "recommendation": "Set a weekly grocery plan to balance impulse restaurant purchases.",
        "supportingInsightType": "topCategory"
      }
      ''';

      final insight = parser.parseResponse(rawJson);

      expect(insight.title, 'Food dominates your monthly budget');
      expect(insight.explanation, contains('₹4,500'));
      expect(insight.recommendation, contains('weekly grocery plan'));
      expect(insight.supportingInsightType, InsightType.topCategory);
    });

    test('parseResponse successfully parses Gemini candidate envelope with markdown code block', () {
      const geminiEnvelope = '''
      {
        "candidates": [
          {
            "content": {
              "parts": [
                {
                  "text": "```json\\n{\\n  \\"title\\": \\"Spending Increased\\",\\n  \\"explanation\\": \\"Spending grew by 50% compared to August.\\",\\n  \\"recommendation\\": \\"Review major discretionary purchases.\\",\\n  \\"supportingInsightType\\": \\"spendingIncrease\\"\\n}\\n```"
                }
              ]
            }
          }
        ]
      }
      ''';

      final insight = parser.parseResponse(geminiEnvelope);

      expect(insight.title, 'Spending Increased');
      expect(insight.explanation, 'Spending grew by 50% compared to August.');
      expect(insight.recommendation, 'Review major discretionary purchases.');
      expect(insight.supportingInsightType, InsightType.spendingIncrease);
    });

    test('parseResponse safely maps unknown or null supportingInsightType to null', () {
      const rawJson = '''
      {
        "title": "Balanced Monthly Outlay",
        "explanation": "Expenses were distributed evenly with no major spikes.",
        "recommendation": "Keep up your current routine.",
        "supportingInsightType": "nonExistentCustomType"
      }
      ''';

      final insight = parser.parseResponse(rawJson);

      expect(insight.title, 'Balanced Monthly Outlay');
      expect(insight.supportingInsightType, isNull);
    });

    test('parseResponse throws AIMalformedResponseException on empty body or invalid JSON', () {
      expect(
        () => parser.parseResponse(''),
        throwsA(isA<AIMalformedResponseException>()),
      );

      expect(
        () => parser.parseResponse('not a json string'),
        throwsA(isA<AIMalformedResponseException>()),
      );

      expect(
        () => parser.parseResponse('{"title": "Only Title"}'),
        throwsA(isA<AIMalformedResponseException>()),
      );
    });
  });
}

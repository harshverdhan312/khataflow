import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/models/insight_type.dart';
import 'package:khata_flow/features/insights/domain/models/ai_insight.dart';
import 'package:khata_flow/features/insights/domain/services/ai_response_validator.dart';

void main() {
  group('AIResponseValidator Tests', () {
    const validator = AIResponseValidator();
    final now = DateTime(2026, 9, 15);

    test('valid insight passes validation and isValid returns true', () {
      final insight = AIInsight(
        title: 'Food spending summary',
        explanation: 'You recorded 12 expenses this period with high food spending.',
        recommendation: 'Plan grocery shopping in advance to reduce impulse orders.',
        supportingInsightType: InsightType.topCategory,
        generatedAt: now,
      );

      expect(() => validator.validate(insight), returnsNormally);
      expect(validator.isValid(insight), isTrue);
    });

    test('empty or whitespace title throws AIValidationException', () {
      final emptyTitle = AIInsight(
        title: '',
        explanation: 'Valid explanation',
        recommendation: 'Valid recommendation',
        generatedAt: now,
      );

      final whitespaceTitle = AIInsight(
        title: '   \n\t  ',
        explanation: 'Valid explanation',
        recommendation: 'Valid recommendation',
        generatedAt: now,
      );

      expect(
        () => validator.validate(emptyTitle),
        throwsA(isA<AIValidationException>()),
      );
      expect(validator.isValid(emptyTitle), isFalse);

      expect(
        () => validator.validate(whitespaceTitle),
        throwsA(isA<AIValidationException>()),
      );
      expect(validator.isValid(whitespaceTitle), isFalse);
    });

    test('excessively long title throws AIValidationException', () {
      final longTitle = AIInsight(
        title: 'A' * (AIResponseValidator.maxTitleLength + 1),
        explanation: 'Valid explanation',
        recommendation: 'Valid recommendation',
        generatedAt: now,
      );

      expect(
        () => validator.validate(longTitle),
        throwsA(isA<AIValidationException>()),
      );
      expect(validator.isValid(longTitle), isFalse);
    });

    test('empty or whitespace explanation throws AIValidationException', () {
      final emptyExplanation = AIInsight(
        title: 'Valid title',
        explanation: '   ',
        recommendation: 'Valid recommendation',
        generatedAt: now,
      );

      expect(
        () => validator.validate(emptyExplanation),
        throwsA(isA<AIValidationException>()),
      );
      expect(validator.isValid(emptyExplanation), isFalse);
    });

    test('excessively long explanation throws AIValidationException', () {
      final longExplanation = AIInsight(
        title: 'Valid title',
        explanation: 'E' * (AIResponseValidator.maxExplanationLength + 1),
        recommendation: 'Valid recommendation',
        generatedAt: now,
      );

      expect(
        () => validator.validate(longExplanation),
        throwsA(isA<AIValidationException>()),
      );
      expect(validator.isValid(longExplanation), isFalse);
    });

    test('empty or whitespace recommendation throws AIValidationException', () {
      final emptyRecommendation = AIInsight(
        title: 'Valid title',
        explanation: 'Valid explanation',
        recommendation: '',
        generatedAt: now,
      );

      expect(
        () => validator.validate(emptyRecommendation),
        throwsA(isA<AIValidationException>()),
      );
      expect(validator.isValid(emptyRecommendation), isFalse);
    });

    test('excessively long recommendation throws AIValidationException', () {
      final longRecommendation = AIInsight(
        title: 'Valid title',
        explanation: 'Valid explanation',
        recommendation: 'R' * (AIResponseValidator.maxRecommendationLength + 1),
        generatedAt: now,
      );

      expect(
        () => validator.validate(longRecommendation),
        throwsA(isA<AIValidationException>()),
      );
      expect(validator.isValid(longRecommendation), isFalse);
    });
  });
}

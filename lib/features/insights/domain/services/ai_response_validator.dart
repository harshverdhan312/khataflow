import '../models/ai_insight.dart';

/// Exception thrown when an AI-generated insight fails structural validation or constraint safety checks.
class AIValidationException implements Exception {
  final String message;

  const AIValidationException(this.message);

  @override
  String toString() => 'AIValidationException: $message';
}

/// Pure domain service responsible for validating the structural integrity, non-emptiness,
/// and bounding constraints of AI-generated insights.
///
/// NOTE: The validator never attempts to "correct" financial figures; authoritative financial
/// facts originate solely from [AIContext].
class AIResponseValidator {
  static const int maxTitleLength = 120;
  static const int maxExplanationLength = 1000;
  static const int maxRecommendationLength = 1000;

  const AIResponseValidator();

  /// Validates an [AIInsight], throwing an [AIValidationException] if any constraint is violated.
  void validate(AIInsight insight) {
    if (insight.title.trim().isEmpty) {
      throw const AIValidationException('Insight title must not be empty or whitespace.');
    }
    if (insight.title.length > maxTitleLength) {
      throw AIValidationException(
        'Insight title exceeds maximum length of $maxTitleLength characters.',
      );
    }

    if (insight.explanation.trim().isEmpty) {
      throw const AIValidationException(
        'Insight explanation must not be empty or whitespace.',
      );
    }
    if (insight.explanation.length > maxExplanationLength) {
      throw AIValidationException(
        'Insight explanation exceeds maximum length of $maxExplanationLength characters.',
      );
    }

    if (insight.recommendation.trim().isEmpty) {
      throw const AIValidationException(
        'Insight recommendation must not be empty or whitespace.',
      );
    }
    if (insight.recommendation.length > maxRecommendationLength) {
      throw AIValidationException(
        'Insight recommendation exceeds maximum length of $maxRecommendationLength characters.',
      );
    }
  }

  /// Returns `true` if the [AIInsight] passes all structural validation checks, otherwise `false`.
  bool isValid(AIInsight insight) {
    try {
      validate(insight);
      return true;
    } catch (_) {
      return false;
    }
  }
}

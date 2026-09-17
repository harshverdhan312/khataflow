import '../../../expense/domain/models/insight_type.dart';

/// Immutable model representing an interpretive AI-generated financial insight.
class AIInsight {
  final String title;
  final String explanation;
  final String recommendation;
  final InsightType? supportingInsightType;
  final DateTime generatedAt;

  const AIInsight({
    required this.title,
    required this.explanation,
    required this.recommendation,
    this.supportingInsightType,
    required this.generatedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIInsight &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          explanation == other.explanation &&
          recommendation == other.recommendation &&
          supportingInsightType == other.supportingInsightType &&
          generatedAt == other.generatedAt;

  @override
  int get hashCode => Object.hash(
        title,
        explanation,
        recommendation,
        supportingInsightType,
        generatedAt,
      );

  @override
  String toString() =>
      'AIInsight(title: $title, explanation: $explanation, recommendation: $recommendation, supportingInsightType: $supportingInsightType, generatedAt: $generatedAt)';
}

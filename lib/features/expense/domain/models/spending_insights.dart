import 'spending_insight.dart';

class SpendingInsights {
  final List<SpendingInsight> insights;

  const SpendingInsights({
    required this.insights,
  });

  bool get isEmpty => insights.isEmpty;
  bool get hasInsights => insights.isNotEmpty;
  bool get isNotEmpty => insights.isNotEmpty;

  SpendingInsight? get highestPriority =>
      insights.isNotEmpty ? insights.first : null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpendingInsights &&
          runtimeType == other.runtimeType &&
          _listEquals(insights, other.insights);

  @override
  int get hashCode => Object.hashAll(insights);

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

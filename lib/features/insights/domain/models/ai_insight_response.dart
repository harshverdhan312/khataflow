import 'ai_insight.dart';

/// Response object encapsulating the generated [AIInsight] and optional provider metadata.
class AIInsightResponse {
  final AIInsight insight;
  final Map<String, String>? providerMetadata;

  const AIInsightResponse({
    required this.insight,
    this.providerMetadata,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIInsightResponse &&
          runtimeType == other.runtimeType &&
          insight == other.insight &&
          _mapEquals(providerMetadata, other.providerMetadata);

  @override
  int get hashCode => Object.hash(
        insight,
        providerMetadata != null ? Object.hashAll(providerMetadata!.entries) : null,
      );

  static bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'AIInsightResponse(insight: $insight, providerMetadata: $providerMetadata)';
}

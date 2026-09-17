import '../../domain/models/ai_context.dart';
import '../../domain/models/ai_insight.dart';
import '../../domain/models/ai_insight_request.dart';

/// In-memory cache for AI insight responses during the current application session.
///
/// Prevents redundant AI API calls when deterministic financial context remains unchanged.
/// Uses a deterministic string fingerprint constructed exclusively from integer amounts,
/// timestamps, counts, and category identifiers (zero floating-point math).
class AIInsightCache {
  final Map<String, AIInsight> _cache = {};

  /// Retrieves a cached [AIInsight] for the given [request] if present and valid.
  AIInsight? get(AIInsightRequest request) {
    final key = _computeCacheKey(request);
    return _cache[key];
  }

  /// Stores a generated [AIInsight] in the cache for the given [request].
  void put(AIInsightRequest request, AIInsight insight) {
    final key = _computeCacheKey(request);
    _cache[key] = insight;
  }

  /// Clears all cached entries.
  void clear() {
    _cache.clear();
  }

  /// Returns the number of cached items.
  int get size => _cache.length;

  /// Computes a deterministic cache key without floating-point math.
  String _computeCacheKey(AIInsightRequest request) {
    final ctx = request.context;
    final fingerprint = _buildContextFingerprint(ctx);
    return '${request.requestType.name}_$fingerprint';
  }

  /// Generates a strict deterministic context fingerprint.
  String _buildContextFingerprint(AIContext ctx) {
    final buffer = StringBuffer();

    // 1. Period boundaries
    buffer.write(
        'period:${ctx.periodStart.millisecondsSinceEpoch}-${ctx.periodEnd.millisecondsSinceEpoch};');

    // 2. Exact integer totals & counts
    buffer.write('currPaise:${ctx.currentMonthTotalPaise};');
    buffer.write('prevPaise:${ctx.previousMonthTotalPaise};');
    buffer.write('currCount:${ctx.currentMonthExpenseCount};');
    buffer.write('prevCount:${ctx.previousMonthExpenseCount};');

    // 3. Category totals
    final sortedCategories = [...ctx.categoryTotals]
      ..sort((a, b) => a.category.name.compareTo(b.category.name));
    buffer.write('catTotals:[');
    for (final cs in sortedCategories) {
      buffer.write('${cs.category.name}:${cs.totalAmountPaise};');
    }
    buffer.write('];');

    // 4. Top category and largest expense
    buffer.write('topCat:${ctx.topCategory?.name ?? "none"};');
    if (ctx.largestExpense != null) {
      buffer.write(
          'largest:${ctx.largestExpense!.amountPaise}:${ctx.largestExpense!.category.name};');
    } else {
      buffer.write('largest:none;');
    }

    // 5. Rule-based insights summary
    buffer.write('ruleInsights:[');
    for (final insight in ctx.ruleBasedInsights.insights) {
      buffer.write('${insight.type.name}:${insight.priority.name};');
    }
    buffer.write('];');

    // 6. Spending trends summary
    buffer.write('dailyTrendsCount:${ctx.spendingTrends.dailySpending.length};');
    buffer.write('monthlyTrendsCount:${ctx.spendingTrends.monthlySpending.length};');

    return buffer.toString();
  }
}

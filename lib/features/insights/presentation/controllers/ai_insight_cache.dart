import '../../domain/models/ai_context.dart';
import '../../domain/models/ai_insight.dart';
import '../../domain/models/ai_insight_request.dart';

/// In-memory cache for AI insight responses during the current application session.
///
/// Prevents redundant AI API calls when deterministic financial context remains unchanged.
/// Uses a deterministic string fingerprint constructed exclusively from integer amounts,
/// timestamps, counts, categories, bounded notes, and rule-based insights (zero floating-point math).
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

    // 3. Category totals (alphabetically sorted)
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
      final exp = ctx.largestExpense!;
      buffer.write(
          'largest:${exp.amountPaise}:${exp.category.name}:${exp.date.millisecondsSinceEpoch}:${exp.note ?? "none"};');
    } else {
      buffer.write('largest:none;');
    }

    // 5. Recent bounded expenses
    buffer.write('recent:[');
    for (final exp in ctx.recentExpenses) {
      buffer.write(
          '${exp.amountPaise}:${exp.category.name}:${exp.date.millisecondsSinceEpoch}:${exp.note ?? "none"};');
    }
    buffer.write('];');

    // 6. Rule-based insights summary
    buffer.write('ruleInsights:[');
    for (final insight in ctx.ruleBasedInsights.insights) {
      buffer.write(
          '${insight.type.name}:${insight.priority.name}:${insight.amountPaise ?? 0};');
    }
    buffer.write('];');

    // 7. Spending trends summary
    buffer.write('dailyTrendsCount:${ctx.spendingTrends.dailySpending.length};');
    buffer.write('weeklyTrendsCount:${ctx.spendingTrends.weeklySpending.length};');
    buffer.write('monthlyTrendsCount:${ctx.spendingTrends.monthlySpending.length};');
    if (ctx.spendingTrends.highestSpendingDay != null) {
      final hsd = ctx.spendingTrends.highestSpendingDay!;
      buffer.write('hsd:${hsd.totalAmountPaise}:${hsd.date.millisecondsSinceEpoch};');
    }

    return buffer.toString();
  }
}

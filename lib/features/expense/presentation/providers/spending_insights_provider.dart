import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/spending_analytics_calculator.dart';
import '../../domain/models/spending_insights_calculator.dart';
import '../../domain/models/spending_trends_calculator.dart';
import '../expense_providers.dart';

export '../../domain/models/insight_priority.dart';
export '../../domain/models/insight_type.dart';
export '../../domain/models/spending_analytics.dart';
export '../../domain/models/spending_insights.dart';
export '../../domain/models/spending_trends.dart';

/// Exposes the reactive [SpendingAnalytics] derived from the current expenses stream.
final spendingAnalyticsProvider = Provider<AsyncValue<SpendingAnalytics>>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  return expensesAsync.whenData((expenses) {
    return deriveSpendingAnalytics(expenses);
  });
});

/// Exposes the reactive [SpendingTrends] derived from the current expenses stream.
final spendingTrendsProvider = Provider<AsyncValue<SpendingTrends>>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  return expensesAsync.whenData((expenses) {
    return deriveSpendingTrends(expenses);
  });
});

/// Exposes the reactive [SpendingInsights] derived from analytics, trends, and raw expenses.
final spendingInsightsProvider = Provider<AsyncValue<SpendingInsights>>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  return expensesAsync.whenData((expenses) {
    final analytics = deriveSpendingAnalytics(expenses);
    final trends = deriveSpendingTrends(expenses);
    return deriveSpendingInsights(
      analytics: analytics,
      trends: trends,
      expenses: expenses,
    );
  });
});

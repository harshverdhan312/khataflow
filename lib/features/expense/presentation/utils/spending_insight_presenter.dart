import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/insight_type.dart';
import '../../domain/models/spending_insight.dart';

class SpendingInsightPresenter {
  /// Returns the semantic icon representing the insight type.
  static IconData getIcon(InsightType type) {
    switch (type) {
      case InsightType.spendingIncrease:
        return Icons.trending_up_rounded;
      case InsightType.spendingDecrease:
        return Icons.trending_down_rounded;
      case InsightType.topCategory:
        return Icons.pie_chart_rounded;
      case InsightType.unusuallyHighDay:
        return Icons.calendar_today_rounded;
      case InsightType.largestExpense:
        return Icons.account_balance_wallet_rounded;
      case InsightType.categoryGrowth:
        return Icons.show_chart_rounded;
      case InsightType.categoryDrop:
        return Icons.waterfall_chart_rounded;
      case InsightType.spendingConcentration:
        return Icons.donut_large_rounded;
      case InsightType.frequentCategory:
        return Icons.repeat_rounded;
      case InsightType.highExpenseCount:
        return Icons.receipt_long_rounded;
    }
  }

  /// Returns the accent theme color based on the insight type.
  static Color getAccentColor(InsightType type) {
    switch (type) {
      case InsightType.spendingIncrease:
        return AppColors.outstandingRed;
      case InsightType.spendingDecrease:
        return AppColors.settledGreen;
      case InsightType.spendingConcentration:
        return AppColors.primary;
      case InsightType.categoryGrowth:
        return AppColors.pendingAmber;
      case InsightType.categoryDrop:
        return AppColors.settledGreen;
      case InsightType.topCategory:
      case InsightType.largestExpense:
      case InsightType.unusuallyHighDay:
      case InsightType.frequentCategory:
      case InsightType.highExpenseCount:
        return AppColors.primaryLight;
    }
  }

  /// Returns the supporting metric badge string for display, if available.
  static String? getSupportingMetric(SpendingInsight insight) {
    if (insight.amountPaise != null) {
      return CurrencyFormatter.formatPaise(insight.amountPaise!);
    }
    if (insight.percentage != null) {
      return '${insight.percentage!.toStringAsFixed(0)}%';
    }
    if (insight.date != null) {
      return insight.date!.toShortDate();
    }
    return null;
  }
}

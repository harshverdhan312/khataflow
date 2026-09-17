import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../expense/domain/models/insight_type.dart';
import '../../domain/models/ai_insight.dart';

/// Presentation card displaying an interpretive AI-generated financial insight.
///
/// Distinct from deterministic M7 cards: displays an "AI-generated" indicator,
/// formatted title, explanation, actionable recommendation, and optional supporting insight link.
class AIInsightCard extends StatelessWidget {
  final AIInsight insight;

  const AIInsightCard({
    super.key,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        DateFormat('MMM d, h:mm a').format(insight.generatedAt);

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Bar & Badges
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                border: const Border(
                  bottom: BorderSide(color: AppColors.borderDark),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 13,
                                color: AppColors.primaryLight,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'AI-generated',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (insight.supportingInsightType != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Based on: ${_getSupportingInsightName(insight.supportingInsightType!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    insight.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Explanation
                  Text(
                    insight.explanation,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Actionable Recommendation Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.borderDark,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 18,
                          color: AppColors.pendingAmber,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recommendation',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.pendingAmber,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                insight.recommendation,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: AppColors.textPrimaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _getSupportingInsightName(InsightType type) {
    switch (type) {
      case InsightType.spendingIncrease:
        return 'Spending increase';
      case InsightType.spendingDecrease:
        return 'Spending decrease';
      case InsightType.topCategory:
        return 'Top category';
      case InsightType.unusuallyHighDay:
        return 'High spending day';
      case InsightType.largestExpense:
        return 'Largest expense';
      case InsightType.categoryGrowth:
        return 'Category growth';
      case InsightType.categoryDrop:
        return 'Category drop';
      case InsightType.spendingConcentration:
        return 'Spending concentration';
      case InsightType.frequentCategory:
        return 'Frequent transactions';
      case InsightType.highExpenseCount:
        return 'Expense volume';
    }
  }
}

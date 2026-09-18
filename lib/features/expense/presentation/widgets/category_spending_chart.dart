import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/expense_category.dart';
import '../../domain/models/category_spending.dart';

/// A dark-theme compatible horizontal bar chart visualizing deterministic category spending.
///
/// Consumes the existing M7.1 [CategorySpending] list from [SpendingAnalytics] without performing financial calculations.
class CategorySpendingChart extends StatelessWidget {
  final List<CategorySpending> categoryTotals;

  const CategorySpendingChart({
    super.key,
    required this.categoryTotals,
  });

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.transport:
        return Icons.directions_car_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.bills:
        return Icons.receipt_rounded;
      case ExpenseCategory.entertainment:
        return Icons.movie_rounded;
      case ExpenseCategory.health:
        return Icons.local_hospital_rounded;
      case ExpenseCategory.education:
        return Icons.school_rounded;
      case ExpenseCategory.other:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return const Color(0xFFF59E0B); // Amber
      case ExpenseCategory.transport:
        return const Color(0xFF3B82F6); // Blue
      case ExpenseCategory.shopping:
        return const Color(0xFFEC4899); // Pink
      case ExpenseCategory.bills:
        return const Color(0xFF8B5CF6); // Purple
      case ExpenseCategory.entertainment:
        return const Color(0xFF10B981); // Emerald
      case ExpenseCategory.health:
        return const Color(0xFFEF4444); // Red
      case ExpenseCategory.education:
        return const Color(0xFF06B6D4); // Cyan
      case ExpenseCategory.other:
        return const Color(0xFF64748B); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    if (categoryTotals.isEmpty) {
      return _buildEmptyState();
    }

    final maxPaise = categoryTotals.isNotEmpty ? categoryTotals.first.totalAmountPaise : 0;
    final totalPaise = categoryTotals.fold<int>(0, (sum, c) => sum + c.totalAmountPaise);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 18,
                    color: AppColors.primaryLight,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'CATEGORY SPENDING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
              Text(
                '${categoryTotals.length} categories',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal Bars List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categoryTotals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = categoryTotals[index];
              final ratio = maxPaise > 0 ? (item.totalAmountPaise / maxPaise).clamp(0.0, 1.0) : 0.0;
              final percent = totalPaise > 0 ? (item.totalAmountPaise / totalPaise * 100) : 0.0;
              final color = _getCategoryColor(item.category);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Category Icon & Name
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          _getCategoryIcon(item.category),
                          size: 14,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.category.displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Percentage
                      Text(
                        '${percent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Amount
                      Text(
                        CurrencyFormatter.formatPaise(item.totalAmountPaise),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Horizontal Bar Indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          color: AppColors.surfaceDark,
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            size: 32,
            color: AppColors.textSecondaryDark.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'No category spending recorded yet',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

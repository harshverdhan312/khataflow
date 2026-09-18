import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../insights/domain/models/ai_request_type.dart';
import '../../../insights/presentation/providers/ai_insights_providers.dart';
import '../../../insights/presentation/widgets/ai_insight_card.dart';
import '../../domain/models/spending_insight.dart';
import '../expense_providers.dart';
import '../providers/spending_insights_provider.dart';
import '../utils/spending_insight_presenter.dart';
import '../widgets/category_spending_chart.dart';
import '../widgets/spending_trend_chart.dart';

class SpendingInsightsScreen extends ConsumerWidget {
  const SpendingInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(spendingInsightsProvider);
    final analyticsAsync = ref.watch(spendingAnalyticsProvider);
    final trendsAsync = ref.watch(spendingTrendsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        title: const Text('Spending Insights'),
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
      ),
      body: insightsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.outstandingRed,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Couldn't load spending insights",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(expensesStreamProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (spendingInsights) {
          if (spendingInsights.isEmpty) {
            return _buildEmptyState();
          }

          final analytics = analyticsAsync.asData?.value;
          final trends = trendsAsync.asData?.value;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              const Text(
                'Understand where your money is going',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 16),

              if (analytics != null && analytics.hasCurrentMonthExpenses) ...[
                _buildSummaryHeader(analytics),
                const SizedBox(height: 16),
              ],

              // 1. Spending Trend (Line Chart)
              if (trends != null) ...[
                SpendingTrendChart(trends: trends),
                const SizedBox(height: 16),
              ],

              // 2. Category Spending (Horizontal Bar Chart)
              if (analytics != null && analytics.categoryTotals.isNotEmpty) ...[
                CategorySpendingChart(categoryTotals: analytics.categoryTotals),
                const SizedBox(height: 16),
              ],

              // 3. Deterministic M7 Insight Cards
              if (spendingInsights.insights.isNotEmpty) ...[
                const Text(
                  'RULE-BASED INSIGHTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 10),
                ...spendingInsights.insights.map((insight) {
                  return _buildInsightCard(insight);
                }),
                const SizedBox(height: 16),
              ],

              // 4. Separated M8 AI Insights Section
              _buildAiSection(
                context,
                ref,
                analytics: analytics,
                trends: trends,
                insights: spendingInsights,
              ),

              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(SpendingAnalytics analytics) {
    final monthName = DateFormat('MMMM').format(analytics.currentPeriodStart);
    final countText = analytics.currentMonthExpenseCount == 1
        ? '1 expense'
        : '${analytics.currentMonthExpenseCount} expenses';

    String momText;
    Color momColor = AppColors.textSecondaryDark;
    if (analytics.monthOverMonthChangePercent != null) {
      final prevMonthName =
          DateFormat('MMMM').format(analytics.previousPeriodStart);
      final pct = analytics.monthOverMonthChangePercent!;
      if (pct > 0) {
        momText = '↑ ${pct.toStringAsFixed(0)}% from $prevMonthName';
        momColor = AppColors.outstandingRed;
      } else if (pct < 0) {
        momText = '↓ ${pct.abs().toStringAsFixed(0)}% from $prevMonthName';
        momColor = AppColors.settledGreen;
      } else {
        momText = 'Same as $prevMonthName';
      }
    } else {
      momText = 'No previous-month comparison';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$monthName Spending'.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatPaise(analytics.currentMonthTotalPaise),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                countText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(color: AppColors.borderDark)),
              const SizedBox(width: 8),
              Text(
                momText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: momColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(SpendingInsight insight) {
    final icon = SpendingInsightPresenter.getIcon(insight.type);
    final accentColor = SpendingInsightPresenter.getAccentColor(insight.type);
    final metric = SpendingInsightPresenter.getSupportingMetric(insight);

    final isHigh = insight.priority == InsightPriority.high;
    final isLow = insight.priority == InsightPriority.low;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isLow ? AppColors.cardDark.withValues(alpha: 0.7) : AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHigh ? accentColor.withValues(alpha: 0.6) : AppColors.borderDark,
          width: isHigh ? 1.5 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isHigh)
                Container(
                  width: 4,
                  color: accentColor,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    insight.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isHigh
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: AppColors.textPrimaryDark,
                                    ),
                                  ),
                                ),
                                if (metric != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      metric,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              insight.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondaryDark,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiSection(
    BuildContext context,
    WidgetRef ref, {
    required SpendingAnalytics? analytics,
    required SpendingTrends? trends,
    required SpendingInsights insights,
  }) {
    final aiState = ref.watch(aiInsightControllerProvider);
    final controller = ref.read(aiInsightControllerProvider.notifier);

    final canRequest = analytics != null &&
        trends != null &&
        analytics.hasCurrentMonthExpenses &&
        !aiState.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'AI Spending Intelligence',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Interpretive analysis and personalized guidance based on your trusted data.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryDark,
          ),
        ),
        const SizedBox(height: 14),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canRequest
                    ? () {
                        controller.requestMonthlySummary(
                          analytics: analytics,
                          trends: trends,
                          insights: insights,
                        );
                      }
                    : null,
                icon: const Icon(Icons.summarize_rounded, size: 16),
                label: const Text('Monthly Summary'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardDark,
                  foregroundColor: AppColors.textPrimaryDark,
                  disabledBackgroundColor:
                      AppColors.cardDark.withValues(alpha: 0.5),
                  disabledForegroundColor: AppColors.textSecondaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: aiState.requestType ==
                                  AIRequestType.monthlySummary &&
                              aiState.isSuccess
                          ? AppColors.primary
                          : AppColors.borderDark,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canRequest
                    ? () {
                        controller.requestSpendingAdvice(
                          analytics: analytics,
                          trends: trends,
                          insights: insights,
                        );
                      }
                    : null,
                icon: const Icon(Icons.lightbulb_rounded, size: 16),
                label: const Text('Spending Advice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardDark,
                  foregroundColor: AppColors.textPrimaryDark,
                  disabledBackgroundColor:
                      AppColors.cardDark.withValues(alpha: 0.5),
                  disabledForegroundColor: AppColors.textSecondaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: aiState.requestType ==
                                  AIRequestType.spendingAdvice &&
                              aiState.isSuccess
                          ? AppColors.primary
                          : AppColors.borderDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Dynamic State Content
        if (aiState.isLoading) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  aiState.requestType == AIRequestType.spendingAdvice
                      ? 'Analyzing spending advice...'
                      : 'Generating monthly summary...',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
        ] else if (aiState.isSuccess && aiState.insight != null) ...[
          AIInsightCard(insight: aiState.insight!),
        ] else if (aiState.isError) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.outstandingRed.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.outstandingRed,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    aiState.errorMessage ??
                        'AI insights are temporarily unavailable.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ),
                if (analytics != null && trends != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      controller.retry(
                        analytics: analytics,
                        trends: trends,
                        insights: insights,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ] else if (aiState.isEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.pendingAmber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    aiState.errorMessage ??
                        'Add some expenses to generate AI spending insights.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No insights yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep recording your expenses and KhataFlow will surface useful spending patterns here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryDark,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../insights/domain/models/ai_request_type.dart';
import '../../../insights/presentation/providers/ai_insights_providers.dart';
import '../../../insights/presentation/widgets/ai_insight_card.dart';
import '../../domain/expense.dart';
import '../../domain/expense_category.dart';
import '../../domain/models/spending_insight.dart';
import '../add_expense_sheet.dart';
import '../expense_detail_sheet.dart';
import '../expense_providers.dart';
import '../providers/spending_insights_provider.dart';
import '../utils/spending_insight_presenter.dart';
import '../widgets/category_spending_chart.dart';
import '../widgets/spending_trend_chart.dart';

/// The dedicated Expenses destination of KhataFlow.
///
/// Features monthly spending summaries, category breakdowns, recent expenses,
/// and integrated AI Spending Intelligence with deterministic M7 fallbacks.
class ExpensesTabScreen extends ConsumerWidget {
  const ExpensesTabScreen({super.key});

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

  Map<DateTime, List<Expense>> _groupByDate(List<Expense> expenses) {
    final grouped = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      final date = DateTime(
        expense.expenseDate.year,
        expense.expenseDate.month,
        expense.expenseDate.day,
      );
      grouped.putIfAbsent(date, () => []).add(expense);
    }
    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (date.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return date.toFormattedDate();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final analyticsAsync = ref.watch(spendingAnalyticsProvider);
    final trendsAsync = ref.watch(spendingTrendsProvider);
    final insightsAsync = ref.watch(spendingInsightsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/branding/khataflow_icon.png',
              height: 26,
              width: 26,
              errorBuilder: (_, _, _) => const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: AppColors.textPrimaryDark,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add Expense',
            icon: const Icon(Icons.add_rounded, color: AppColors.primaryLight),
            onPressed: () => context.push('/expenses/add'),
          ),
          IconButton(
            tooltip: 'All Expenses History',
            icon: const Icon(Icons.history_rounded, color: AppColors.textSecondaryDark),
            onPressed: () => context.push('/expenses/history'),
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.outstandingRed),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load expenses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryDark),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(expensesStreamProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (expenses) {
          final analytics = analyticsAsync.asData?.value;
          final trends = trendsAsync.asData?.value;
          final insights = insightsAsync.asData?.value ?? const SpendingInsights(insights: []);

          if (expenses.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(expensesStreamProvider);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Section Title
                const Text(
                  'Spending',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. Spending Hero Card (This Month)
                _buildSpendingHeroCard(context, analytics, trends),
                const SizedBox(height: 16),

                // 2. Spending Trend Chart (M7.2 Line Chart)
                if (trends != null) ...[
                  SpendingTrendChart(trends: trends),
                  const SizedBox(height: 16),
                ],

                // 3. Category Spending Chart (M7.1 Horizontal Bar Chart)
                if (analytics != null && analytics.categoryTotals.isNotEmpty) ...[
                  CategorySpendingChart(categoryTotals: analytics.categoryTotals),
                  const SizedBox(height: 16),
                ],

                // 4. Rule-Based Insights (Deterministic M7)
                if (insights.insights.isNotEmpty) ...[
                  _buildDeterministicInsightsList(insights.insights),
                  const SizedBox(height: 16),
                ],

                // 5. AI Spending Intelligence Section
                _buildAiSpendingIntelligenceSection(
                  context,
                  ref,
                  analytics: analytics,
                  trends: trends,
                  insights: insights,
                ),
                const SizedBox(height: 20),

                // 6. Recent Expenses List
                _buildRecentExpensesSection(context, expenses),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddExpenseSheet.show(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 54,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No expenses recorded yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the microphone on Home or the + button below to log an expense.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryDark,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => AddExpenseSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingHeroCard(
    BuildContext context,
    SpendingAnalytics? analytics,
    SpendingTrends? trends,
  ) {
    final totalPaise = analytics?.currentMonthTotalPaise ?? 0;
    final count = analytics?.currentMonthExpenseCount ?? 0;
    final momChange = analytics?.monthOverMonthChangePercent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'THIS MONTH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.textSecondaryDark,
                ),
              ),
              Text(
                count == 1 ? '1 expense' : '$count expenses',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            CurrencyFormatter.formatPaise(totalPaise),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),
          if (momChange != null) ...[
            Row(
              children: [
                Icon(
                  momChange > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 16,
                  color: momChange > 0 ? AppColors.outstandingRed : AppColors.settledGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  '${momChange > 0 ? '+' : ''}${momChange.toStringAsFixed(1)}% vs last period',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: momChange > 0 ? AppColors.outstandingRed : AppColors.settledGreen,
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Current billing cycle',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiSpendingIntelligenceSection(
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
                      size: 15,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Spending Intelligence',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.push('/expenses/insights'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Full Analysis',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Interpretive analysis and advice grounded in your real SQLite expenses.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryDark,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canRequest
                      ? () {
                          controller.requestMonthlySummary(
                            analytics: analytics,
                            trends: trends,
                            insights: insights,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.summarize_outlined, size: 15),
                  label: const Text('Monthly Summary', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimaryDark,
                    side: BorderSide(
                      color: aiState.requestType == AIRequestType.monthlySummary && aiState.isSuccess
                          ? AppColors.primary
                          : AppColors.borderDark,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canRequest
                      ? () {
                          controller.requestSpendingAdvice(
                            analytics: analytics,
                            trends: trends,
                            insights: insights,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 15),
                  label: const Text('Spending Advice', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimaryDark,
                    side: BorderSide(
                      color: aiState.requestType == AIRequestType.spendingAdvice && aiState.isSuccess
                          ? AppColors.primary
                          : AppColors.borderDark,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),

          // Dynamic state rendering
          if (aiState.isLoading) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    aiState.requestType == AIRequestType.spendingAdvice
                        ? 'Analyzing spending advice...'
                        : 'Generating monthly summary...',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                  ),
                ],
              ),
            ),
          ] else if (aiState.isSuccess && aiState.insight != null) ...[
            AIInsightCard(insight: aiState.insight!),
          ] else if (aiState.isError) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outstandingRed.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.outstandingRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aiState.errorMessage ?? 'AI insights are temporarily unavailable.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimaryDark),
                    ),
                  ),
                  if (analytics != null && trends != null) ...[
                    TextButton(
                      onPressed: () {
                        controller.retry(
                          analytics: analytics,
                          trends: trends,
                          insights: insights,
                        );
                      },
                      child: const Text('Retry', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (aiState.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              aiState.errorMessage ?? 'Add some expenses to generate AI spending insights.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeterministicInsightsList(List<SpendingInsight> insights) {
    final topInsights = insights.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Spending Patterns',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryDark,
          ),
        ),
        const SizedBox(height: 10),
        ...topInsights.map((insight) {
          final icon = SpendingInsightPresenter.getIcon(insight.type);
          final color = SpendingInsightPresenter.getAccentColor(insight.type);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        insight.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentExpensesSection(BuildContext context, List<Expense> expenses) {
    final grouped = _groupByDate(expenses.take(15).toList());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Expenses',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryDark,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/expenses/history'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...grouped.entries.map((entry) {
          final dateHeader = _formatDateHeader(entry.key);
          final dayExpenses = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Text(
                  dateHeader,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
              ...dayExpenses.map((expense) {
                return Card(
                  color: AppColors.cardDark,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.borderDark),
                  ),
                  child: InkWell(
                    onTap: () => ExpenseDetailSheet.show(context, expense: expense),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getCategoryIcon(expense.category),
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  expense.category.displayName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  expense.note != null && expense.note!.isNotEmpty
                                      ? expense.note!
                                      : expense.expenseDate.toRelativeDisplay(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.formatPaise(expense.amountPaise),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}

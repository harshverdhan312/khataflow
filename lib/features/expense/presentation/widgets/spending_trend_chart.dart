import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/spending_trend_point.dart';
import '../../domain/models/spending_trends.dart';

enum TrendViewMode { daily, weekly, monthly }

/// A dark-theme compatible, responsive Line Chart visualizing deterministic spending trends.
///
/// Consumes the existing M7.2 [SpendingTrends] model without performing financial calculations.
class SpendingTrendChart extends StatefulWidget {
  final SpendingTrends trends;

  const SpendingTrendChart({
    super.key,
    required this.trends,
  });

  @override
  State<SpendingTrendChart> createState() => _SpendingTrendChartState();
}

class _SpendingTrendChartState extends State<SpendingTrendChart> {
  TrendViewMode _mode = TrendViewMode.daily;
  int? _selectedPointIndex;

  List<SpendingTrendPoint> get _currentPoints {
    switch (_mode) {
      case TrendViewMode.daily:
        return widget.trends.dailySpending;
      case TrendViewMode.weekly:
        return widget.trends.weeklySpending;
      case TrendViewMode.monthly:
        return widget.trends.monthlySpending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _currentPoints;
    final hasData = points.isNotEmpty && points.any((p) => p.totalAmountPaise > 0);

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
          // Header: Title & Mode Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 18,
                    color: AppColors.primaryLight,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'SPENDING TREND',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
              _buildModeSelector(),
            ],
          ),
          const SizedBox(height: 16),

          if (!hasData)
            _buildEmptyTrendState()
          else
            _buildChartArea(points),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDark),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton('Daily', TrendViewMode.daily),
          _buildModeButton('Weekly', TrendViewMode.weekly),
          _buildModeButton('Monthly', TrendViewMode.monthly),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, TrendViewMode mode) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mode = mode;
          _selectedPointIndex = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTrendState() {
    return Container(
      height: 140,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.stacked_line_chart_rounded,
            size: 32,
            color: AppColors.textSecondaryDark.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'No spending trend recorded for this period',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartArea(List<SpendingTrendPoint> points) {
    final maxPaise = points.map((p) => p.totalAmountPaise).fold<int>(0, math.max);
    final selectedPoint = _selectedPointIndex != null &&
            _selectedPointIndex! >= 0 &&
            _selectedPointIndex! < points.length
        ? points[_selectedPointIndex!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Peak / Selected Point Tooltip Inspector
        Container(
          height: 36,
          alignment: Alignment.centerLeft,
          child: selectedPoint != null
              ? Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatPointDate(selectedPoint),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const Text(' : ', style: TextStyle(color: AppColors.textSecondaryDark)),
                    Text(
                      CurrencyFormatter.formatPaise(selectedPoint.totalAmountPaise),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Peak: ${CurrencyFormatter.formatPaise(maxPaise)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const Text(
                      'Tap points to inspect',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),

        // Custom Canvas Line Chart
        SizedBox(
          height: 160,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanDown: (details) => _handleTouch(details.localPosition, constraints.maxWidth, points),
                onPanUpdate: (details) => _handleTouch(details.localPosition, constraints.maxWidth, points),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 160),
                  painter: _SpendingTrendPainter(
                    points: points,
                    maxPaise: maxPaise > 0 ? maxPaise : 1,
                    selectedIndex: _selectedPointIndex,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // X-Axis Date Labels
        _buildXAxisLabels(points),
      ],
    );
  }

  void _handleTouch(Offset localPosition, double width, List<SpendingTrendPoint> points) {
    if (points.isEmpty) return;
    final stepWidth = width / (points.length <= 1 ? 1 : points.length - 1);
    final touchedIndex = (localPosition.dx / stepWidth).round().clamp(0, points.length - 1);
    if (_selectedPointIndex != touchedIndex) {
      setState(() {
        _selectedPointIndex = touchedIndex;
      });
    }
  }

  String _formatPointDate(SpendingTrendPoint point) {
    switch (_mode) {
      case TrendViewMode.daily:
        return DateFormat('EEE, d MMM').format(point.periodStart);
      case TrendViewMode.weekly:
        final startStr = DateFormat('d MMM').format(point.periodStart);
        final endStr = DateFormat('d MMM').format(point.periodEnd.subtract(const Duration(days: 1)));
        return '$startStr - $endStr';
      case TrendViewMode.monthly:
        return DateFormat('MMMM yyyy').format(point.periodStart);
    }
  }

  Widget _buildXAxisLabels(List<SpendingTrendPoint> points) {
    if (points.isEmpty) return const SizedBox.shrink();

    // Select up to 5 evenly distributed label points to prevent crowding
    final labelCount = math.min(points.length, 5);
    final indices = <int>[];
    if (points.length <= 5) {
      indices.addAll(List.generate(points.length, (i) => i));
    } else {
      for (int i = 0; i < labelCount; i++) {
        final idx = ((points.length - 1) * i / (labelCount - 1)).round();
        if (!indices.contains(idx)) {
          indices.add(idx);
        }
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: indices.map((idx) {
        final point = points[idx];
        String text;
        switch (_mode) {
          case TrendViewMode.daily:
            text = DateFormat('d MMM').format(point.periodStart);
            break;
          case TrendViewMode.weekly:
            text = 'W${idx + 1}';
            break;
          case TrendViewMode.monthly:
            text = DateFormat('MMM').format(point.periodStart);
            break;
        }

        final isSelected = _selectedPointIndex == idx;
        return Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primaryLight : AppColors.textSecondaryDark,
          ),
        );
      }).toList(),
    );
  }
}

class _SpendingTrendPainter extends CustomPainter {
  final List<SpendingTrendPoint> points;
  final int maxPaise;
  final int? selectedIndex;

  _SpendingTrendPainter({
    required this.points,
    required this.maxPaise,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paddingBottom = 16.0;
    final paddingTop = 12.0;
    final chartHeight = size.height - paddingBottom - paddingTop;
    final width = size.width;

    // 1. Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = AppColors.borderDark.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 2; i++) {
      final y = paddingTop + (chartHeight * i / 2);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // 2. Compute point coordinates
    final numPoints = points.length;
    final stepX = numPoints <= 1 ? 0.0 : width / (numPoints - 1);
    final offsets = <Offset>[];

    for (int i = 0; i < numPoints; i++) {
      final x = numPoints <= 1 ? width / 2 : i * stepX;
      final ratio = (points[i].totalAmountPaise / maxPaise).clamp(0.0, 1.0);
      final y = paddingTop + chartHeight * (1.0 - ratio);
      offsets.add(Offset(x, y));
    }

    if (offsets.length == 1) {
      // Single point rendering
      final dotPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill;
      canvas.drawCircle(offsets[0], 5, dotPaint);
      return;
    }

    // 3. Build line & gradient fill paths
    final linePath = Path();
    final fillPath = Path();

    linePath.moveTo(offsets[0].dx, offsets[0].dy);
    fillPath.moveTo(offsets[0].dx, size.height - paddingBottom);
    fillPath.lineTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];

      final controlX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(offsets.last.dx, size.height - paddingBottom);
    fillPath.close();

    // 4. Draw Gradient Fill under line
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.35),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, paddingTop, width, chartHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 5. Draw glowing Line
    final linePaint = Paint()
      ..color = AppColors.primaryLight
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // 6. Draw dots & selected indicator
    for (int i = 0; i < offsets.length; i++) {
      final isSelected = selectedIndex == i;
      final hasSpending = points[i].totalAmountPaise > 0;

      if (isSelected) {
        // Selected highlight
        final outerPaint = Paint()
          ..color = AppColors.primary.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(offsets[i], 8, outerPaint);

        final innerPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(offsets[i], 4, innerPaint);
      } else if (hasSpending) {
        final dotPaint = Paint()
          ..color = AppColors.primaryLight
          ..style = PaintingStyle.fill;
        canvas.drawCircle(offsets[i], 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpendingTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxPaise != maxPaise ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

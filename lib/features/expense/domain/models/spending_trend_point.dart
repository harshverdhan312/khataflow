class SpendingTrendPoint {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalAmountPaise;

  const SpendingTrendPoint({
    required this.periodStart,
    required this.periodEnd,
    required this.totalAmountPaise,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpendingTrendPoint &&
          runtimeType == other.runtimeType &&
          periodStart == other.periodStart &&
          periodEnd == other.periodEnd &&
          totalAmountPaise == other.totalAmountPaise;

  @override
  int get hashCode => Object.hash(periodStart, periodEnd, totalAmountPaise);
}

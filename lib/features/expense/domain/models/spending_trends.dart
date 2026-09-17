import '../expense_category.dart';
import 'spending_trend_point.dart';

class HighestSpendingDay {
  final DateTime date;
  final int totalAmountPaise;

  const HighestSpendingDay({
    required this.date,
    required this.totalAmountPaise,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighestSpendingDay &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          totalAmountPaise == other.totalAmountPaise;

  @override
  int get hashCode => Object.hash(date, totalAmountPaise);
}

class CategoryTrend {
  final ExpenseCategory category;
  final List<SpendingTrendPoint> points;

  const CategoryTrend({
    required this.category,
    required this.points,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryTrend &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          _listEquals(points, other.points);

  @override
  int get hashCode => Object.hash(category, Object.hashAll(points));

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

class SpendingTrends {
  final List<SpendingTrendPoint> dailySpending;
  final List<SpendingTrendPoint> weeklySpending;
  final List<SpendingTrendPoint> monthlySpending;
  final List<CategoryTrend> categoryTrends;
  final HighestSpendingDay? highestSpendingDay;

  const SpendingTrends({
    required this.dailySpending,
    required this.weeklySpending,
    required this.monthlySpending,
    required this.categoryTrends,
    this.highestSpendingDay,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpendingTrends &&
          runtimeType == other.runtimeType &&
          _listEquals(dailySpending, other.dailySpending) &&
          _listEquals(weeklySpending, other.weeklySpending) &&
          _listEquals(monthlySpending, other.monthlySpending) &&
          _listEquals(categoryTrends, other.categoryTrends) &&
          highestSpendingDay == other.highestSpendingDay;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(dailySpending),
        Object.hashAll(weeklySpending),
        Object.hashAll(monthlySpending),
        Object.hashAll(categoryTrends),
        highestSpendingDay,
      );

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

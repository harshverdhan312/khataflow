import '../expense_category.dart';
import 'insight_priority.dart';
import 'insight_type.dart';

class SpendingInsight {
  final InsightType type;
  final InsightPriority priority;
  final String title;
  final String description;
  final int? amountPaise;
  final ExpenseCategory? category;
  final DateTime? date;
  final double? percentage;

  const SpendingInsight({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    this.amountPaise,
    this.category,
    this.date,
    this.percentage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpendingInsight &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          priority == other.priority &&
          title == other.title &&
          description == other.description &&
          amountPaise == other.amountPaise &&
          category == other.category &&
          date == other.date &&
          percentage == other.percentage;

  @override
  int get hashCode => Object.hash(
        type,
        priority,
        title,
        description,
        amountPaise,
        category,
        date,
        percentage,
      );
}

import '../expense_category.dart';

class CategorySpending {
  final ExpenseCategory category;
  final int totalAmountPaise;

  const CategorySpending({
    required this.category,
    required this.totalAmountPaise,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategorySpending &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          totalAmountPaise == other.totalAmountPaise;

  @override
  int get hashCode => Object.hash(category, totalAmountPaise);
}

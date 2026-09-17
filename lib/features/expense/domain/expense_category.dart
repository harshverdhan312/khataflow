enum ExpenseCategory {
  food,
  transport,
  shopping,
  bills,
  entertainment,
  health,
  education,
  other;

  String toDbValue() {
    switch (this) {
      case ExpenseCategory.food:
        return 'FOOD';
      case ExpenseCategory.transport:
        return 'TRANSPORT';
      case ExpenseCategory.shopping:
        return 'SHOPPING';
      case ExpenseCategory.bills:
        return 'BILLS';
      case ExpenseCategory.entertainment:
        return 'ENTERTAINMENT';
      case ExpenseCategory.health:
        return 'HEALTH';
      case ExpenseCategory.education:
        return 'EDUCATION';
      case ExpenseCategory.other:
        return 'OTHER';
    }
  }

  static ExpenseCategory fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'FOOD':
        return ExpenseCategory.food;
      case 'TRANSPORT':
        return ExpenseCategory.transport;
      case 'SHOPPING':
        return ExpenseCategory.shopping;
      case 'BILLS':
        return ExpenseCategory.bills;
      case 'ENTERTAINMENT':
        return ExpenseCategory.entertainment;
      case 'HEALTH':
        return ExpenseCategory.health;
      case 'EDUCATION':
        return ExpenseCategory.education;
      case 'OTHER':
      default:
        return ExpenseCategory.other;
    }
  }

  static ExpenseCategory? tryFromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'FOOD':
        return ExpenseCategory.food;
      case 'TRANSPORT':
        return ExpenseCategory.transport;
      case 'SHOPPING':
        return ExpenseCategory.shopping;
      case 'BILLS':
        return ExpenseCategory.bills;
      case 'ENTERTAINMENT':
        return ExpenseCategory.entertainment;
      case 'HEALTH':
        return ExpenseCategory.health;
      case 'EDUCATION':
        return ExpenseCategory.education;
      case 'OTHER':
        return ExpenseCategory.other;
      default:
        return null;
    }
  }

  String get displayName {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.bills:
        return 'Bills';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.health:
        return 'Health';
      case ExpenseCategory.education:
        return 'Education';
      case ExpenseCategory.other:
        return 'Other';
    }
  }
}

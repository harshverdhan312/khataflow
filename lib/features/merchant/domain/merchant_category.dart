enum MerchantCategory {
  grocery,
  milk,
  laundry,
  other;

  String toDbValue() {
    switch (this) {
      case MerchantCategory.grocery:
        return 'GROCERY';
      case MerchantCategory.milk:
        return 'MILK';
      case MerchantCategory.laundry:
        return 'LAUNDRY';
      case MerchantCategory.other:
        return 'OTHER';
    }
  }

  static MerchantCategory fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'GROCERY':
        return MerchantCategory.grocery;
      case 'MILK':
        return MerchantCategory.milk;
      case 'LAUNDRY':
        return MerchantCategory.laundry;
      case 'OTHER':
      default:
        return MerchantCategory.other;
    }
  }

  String get displayName {
    switch (this) {
      case MerchantCategory.grocery:
        return 'Grocery';
      case MerchantCategory.milk:
        return 'Milk & Dairy';
      case MerchantCategory.laundry:
        return 'Laundry';
      case MerchantCategory.other:
        return 'Other';
    }
  }
}

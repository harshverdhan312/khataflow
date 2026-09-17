import 'package:flutter/foundation.dart';
import '../../expense/domain/expense_category.dart';
import '../../merchant/domain/merchant_category.dart';

/// Single authoritative deterministic resolver for mapping spoken or textual category references
/// to strongly-typed [ExpenseCategory] and [MerchantCategory] enums.
///
/// Shared across both deterministic M5 voice command parser and M8.6.4 AI semantic resolver.
@immutable
class DeterministicCategoryResolver {
  const DeterministicCategoryResolver();

  /// Resolves [text] to an [ExpenseCategory] strictly and deterministically.
  ///
  /// Returns `null` if the input is not recognized as a valid expense category.
  ExpenseCategory? resolveExpenseCategory(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // 1. Direct DB Value or Enum Name Check
    final direct = ExpenseCategory.tryFromDbValue(clean);
    if (direct != null) return direct;

    for (final cat in ExpenseCategory.values) {
      if (clean == cat.name.toLowerCase() || clean == cat.displayName.toLowerCase()) {
        return cat;
      }
    }

    // 2. Keyword & Multi-lingual matching
    // Food
    if (_containsAnyWord(clean, [
      'food', 'khana', 'khaana', 'lunch', 'dinner', 'breakfast', 'restaurant',
      'meal', 'snacks', 'snack', 'tea', 'coffee', 'chai', 'nashta', 'naashta',
      'roti', 'sabzi', 'sabji', 'mithai', 'burger', 'pizza', 'bakery', 'sweets',
      'sweet', 'खाने', 'खाना', 'लंच', 'डिनर', 'नाश्ता', 'चाय', 'कॉफी', 'भोजन', 'सब्जी'
    ])) {
      return ExpenseCategory.food;
    }

    // Transport
    if (_containsAnyWord(clean, [
      'transport', 'transportation', 'auto', 'cab', 'taxi', 'metro', 'bus',
      'train', 'petrol', 'fuel', 'diesel', 'uber', 'ola', 'flight', 'rickshaw',
      'auto rickshaw', 'parking', 'toll', 'yatra', 'यात्रा', 'ऑटो', 'कैब',
      'टैक्सी', 'मेट्रो', 'बस', 'ट्रेन', 'पेट्रोल', 'डीजल', 'किराया'
    ])) {
      return ExpenseCategory.transport;
    }

    // Shopping
    if (_containsAnyWord(clean, [
      'shopping', 'clothes', 'clothing', 'groceries', 'grocery', 'shirt',
      'shoes', 'shoe', 'pants', 'pant', 'dress', 'supermarket', 'mall', 'bag',
      'jeans', 'tshirt', 't-shirt', 'samaan', 'saman', 'kapde', 'kapda',
      'kharidari', 'kharidaari', 'kapdo', 'कपड़े', 'सामान', 'खरीदारी', 'कपड़ा', 'शॉपिंग'
    ])) {
      return ExpenseCategory.shopping;
    }

    // Bills
    if (_containsAnyWord(clean, [
      'bills', 'bill', 'electricity', 'recharge', 'mobile bill', 'internet',
      'rent', 'wifi', 'dth', 'water bill', 'gas bill', 'utility', 'bijli',
      'bijli bill', 'kiraya', 'makaan kiraya', 'bijlee', 'बिजली', 'बिल',
      'रिचार्ज', 'किराया', 'इंटरनेट'
    ])) {
      return ExpenseCategory.bills;
    }

    // Entertainment
    if (_containsAnyWord(clean, [
      'entertainment', 'movie', 'movies', 'cinema', 'gaming', 'game',
      'movie ticket', 'netflix', 'theatre', 'concert', 'match', 'hotstar',
      'prime', 'film', 'picture', 'cinema hall', 'सिनेमा', 'मूवी', 'गेमिंग',
      'मनोरंजन', 'फिल्म'
    ])) {
      return ExpenseCategory.entertainment;
    }

    // Health
    if (_containsAnyWord(clean, [
      'health', 'medicine', 'medicines', 'doctor', 'hospital', 'pharmacy',
      'clinic', 'tablet', 'tablets', 'injection', 'medical', 'treatment',
      'checkup', 'dawai', 'dawa', 'dawaeen', 'dawaiyan', 'ilaaj', 'aspataal',
      'दवाई', 'दवा', 'डॉक्टर', 'अस्पताल', 'इलाज', 'मेडिकल', 'स्वास्थ्य'
    ])) {
      return ExpenseCategory.health;
    }

    // Education
    if (_containsAnyWord(clean, [
      'education', 'course', 'books', 'book', 'fees', 'fee', 'tuition',
      'school', 'college', 'coaching', 'class', 'classes', 'stationery',
      'exam fee', 'padhai', 'kitab', 'kitabein', 'kitabo', 'shiksha',
      'पढ़ाई', 'किताब', 'किताबें', 'फीस', 'ट्यूशन', 'शिक्षा', 'स्कूल', 'कॉलेज'
    ])) {
      return ExpenseCategory.education;
    }

    return null;
  }

  /// Resolves [text] to a [MerchantCategory] strictly and deterministically.
  ///
  /// Returns `null` if the input is not recognized as a valid merchant category.
  MerchantCategory? resolveMerchantCategory(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // Direct match
    if (clean == 'grocery' || clean == 'groceries' || clean == 'kiryana' || clean == 'kirana') {
      return MerchantCategory.grocery;
    }
    if (clean == 'milk' || clean == 'dairy') {
      return MerchantCategory.milk;
    }
    if (clean == 'laundry' || clean == 'dry clean') {
      return MerchantCategory.laundry;
    }
    if (clean == 'other') {
      return MerchantCategory.other;
    }

    for (final cat in MerchantCategory.values) {
      if (clean == cat.name.toLowerCase() ||
          clean == cat.displayName.toLowerCase() ||
          clean == cat.toDbValue().toLowerCase()) {
        return cat;
      }
    }

    // Grocery: sabji, sabzi, sabji wala, vegetable, grocery, kiryana, general store
    if (clean.contains('sabji') ||
        clean.contains('sabzi') ||
        clean.contains('vegetable') ||
        clean.contains('grocery') ||
        clean.contains('kiryana') ||
        clean.contains('kirana') ||
        clean.contains('general store')) {
      return MerchantCategory.grocery;
    }

    // Milk & Dairy: doodh, doodh wala, milk, dairy
    if (clean.contains('doodh') ||
        clean.contains('milk') ||
        clean.contains('dairy')) {
      return MerchantCategory.milk;
    }

    // Laundry: dhobi, laundry, dry clean
    if (clean.contains('dhobi') ||
        clean.contains('laundry') ||
        clean.contains('dry clean')) {
      return MerchantCategory.laundry;
    }

    return null;
  }

  bool _containsAnyWord(String text, List<String> patterns) {
    for (final pattern in patterns) {
      if (RegExp(r'[\u0900-\u097F]').hasMatch(pattern)) {
        if (text.contains(pattern)) return true;
      } else {
        final regex = RegExp(r'\b' + RegExp.escape(pattern) + r'\b', caseSensitive: false);
        if (regex.hasMatch(text)) return true;
      }
    }
    return false;
  }
}

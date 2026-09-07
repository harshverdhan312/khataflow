import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _inrWholeFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Converts paise (int) to formatted INR string (e.g. 77050 -> ₹770.50, 77000 -> ₹770)
  static String formatPaise(int paise, {bool hideZeroDecimals = true}) {
    final double rupees = paise / 100.0;
    if (hideZeroDecimals && paise % 100 == 0) {
      return _inrWholeFormatter.format(rupees);
    }
    return _inrFormatter.format(rupees);
  }

  /// Converts paise (int) to standard decimal string for UPI intent amount (e.g. 77050 -> "770.50", 77000 -> "770.00")
  static String paiseToUpiAmount(int paise) {
    return (paise / 100.0).toStringAsFixed(2);
  }

  /// Converts rupees decimal input to integer paise (e.g. 770.50 -> 77050)
  static int rupeesToPaise(double rupees) {
    return (rupees * 100).round();
  }

  /// Parses a user input string (e.g. "770.50", "770") to integer paise.
  /// Throws FormatException if invalid.
  static int parseInputToPaise(String input) {
    final cleaned = input.replaceAll('₹', '').replaceAll(',', '').trim();
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) {
      throw const FormatException('Invalid amount format');
    }
    return (parsed * 100).round();
  }
}

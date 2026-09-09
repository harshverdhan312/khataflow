import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _integerGroupFormatter = NumberFormat('#,##,##0', 'en_IN');

  /// Converts paise (int) to formatted INR string without floating point arithmetic.
  /// (e.g. 77050 -> ₹770.50, 77000 -> ₹770, 50 -> ₹0.50, 10050 -> ₹100.50, 999999 -> ₹9,999.99)
  static String formatPaise(int paise, {bool hideZeroDecimals = true}) {
    final bool isNegative = paise < 0;
    final int absPaise = paise.abs();
    final int rupees = absPaise ~/ 100;
    final int paiseRemainder = absPaise % 100;

    final String formattedRupees = _integerGroupFormatter.format(rupees);
    final String prefix = isNegative ? '-₹' : '₹';

    if (hideZeroDecimals && paiseRemainder == 0) {
      return '$prefix$formattedRupees';
    }

    final String paddedPaise = paiseRemainder.toString().padLeft(2, '0');
    return '$prefix$formattedRupees.$paddedPaise';
  }

  /// Converts paise (int) to standard decimal string for UPI intent amount (e.g. 77050 -> "770.50", 100 -> "1.00")
  static String paiseToUpiAmount(int paise) {
    final int rupees = paise ~/ 100;
    final int paiseRemainder = paise % 100;
    return '$rupees.${paiseRemainder.toString().padLeft(2, '0')}';
  }

  /// Converts integer rupees input to integer paise.
  static int rupeesToPaise(int rupees) {
    return rupees * 100;
  }

  /// Parses a user input string (e.g. "770.50", "770", "0.50") to integer paise without double conversion.
  /// Throws FormatException if invalid or <= 0.
  static int parseInputToPaise(String input) {
    final cleaned = input.replaceAll('₹', '').replaceAll(',', '').trim();
    if (cleaned.isEmpty) {
      throw const FormatException('Invalid amount format');
    }

    final regex = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!regex.hasMatch(cleaned)) {
      throw const FormatException('Invalid amount format');
    }

    final parts = cleaned.split('.');
    final int rupees = int.parse(parts[0]);
    int paise = 0;
    if (parts.length > 1) {
      final decimalPart = parts[1];
      if (decimalPart.length == 1) {
        paise = int.parse(decimalPart) * 10;
      } else if (decimalPart.length == 2) {
        paise = int.parse(decimalPart);
      }
    }

    final int totalPaise = (rupees * 100) + paise;
    if (totalPaise <= 0) {
      throw const FormatException('Amount must be greater than zero');
    }
    return totalPaise;
  }
}


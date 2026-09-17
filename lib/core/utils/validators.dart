import 'currency_formatter.dart';

class Validators {
  // UPI VPA Regex standard: username@bank/handle
  static final RegExp _vpaRegex = RegExp(
    r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$',
  );

  // 10-digit Indian Mobile Number
  static final RegExp _phoneRegex = RegExp(
    r'^[6-9]\d{9}$',
  );

  static String? validateMerchantName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Merchant name is required';
    }
    if (value.trim().length < 2) {
      return 'Merchant name must be at least 2 characters';
    }
    if (value.trim().length > 100) {
      return 'Merchant name must be less than 100 characters';
    }
    return null;
  }

  static String? validateUpiVpa(String? value, {bool isOptional = false}) {
    if (value == null || value.trim().isEmpty) {
      return isOptional ? null : 'UPI ID is required';
    }
    final trimmed = value.trim();
    if (!_vpaRegex.hasMatch(trimmed)) {
      return 'Enter a valid UPI ID (e.g. merchant@upi, 9876543210@paytm)';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-+()]'), '');
    final standardNumber = cleaned.startsWith('91') && cleaned.length == 12
        ? cleaned.substring(2)
        : cleaned;

    if (!_phoneRegex.hasMatch(standardNumber)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  static String? validatePurchaseAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final cleaned = value.replaceAll('₹', '').replaceAll(',', '').trim();
    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return 'Enter a valid number';
    }
    if (parsed <= 0) {
      return 'Amount must be greater than ₹0';
    }
    if (parsed > 1000000) {
      return 'Amount exceeds maximum limit (₹10,00,000)';
    }
    return null;
  }

  static String? validatePurchaseNote(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Note / item description is required';
    }
    if (value.trim().length > 200) {
      return 'Note must be less than 200 characters';
    }
    return null;
  }

  static String? validateExpenseAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final cleaned = value.replaceAll('₹', '').replaceAll(',', '').trim();
    try {
      final paise = CurrencyFormatter.parseInputToPaise(cleaned);
      if (paise > 100000000) {
        return 'Amount exceeds maximum limit (₹10,00,000)';
      }
    } on FormatException catch (e) {
      if (e.message.contains('greater than zero')) {
        return 'Amount must be greater than ₹0';
      }
      return 'Enter a valid amount (e.g. 250 or 99.50)';
    } catch (_) {
      return 'Enter a valid amount';
    }
    return null;
  }

  static String? validateExpenseNote(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Expense note is optional
    }
    if (value.trim().length > 200) {
      return 'Note must be less than 200 characters';
    }
    return null;
  }
}

abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => 'AppException: $message (code: $code)';
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.code]);
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.code]);
}

class MerchantNotFoundException extends AppException {
  const MerchantNotFoundException([String message = 'Merchant not found'])
      : super(message, 'MERCHANT_NOT_FOUND');
}

class InvalidVpaException extends AppException {
  const InvalidVpaException([String message = 'Invalid UPI VPA address'])
      : super(message, 'INVALID_VPA');
}

class InvalidAmountException extends AppException {
  const InvalidAmountException([String message = 'Amount must be greater than zero'])
      : super(message, 'INVALID_AMOUNT');
}

class ExpenseNotFoundException extends AppException {
  const ExpenseNotFoundException([String message = 'Expense not found'])
      : super(message, 'EXPENSE_NOT_FOUND');
}

class SettlementException extends AppException {
  const SettlementException(super.message, [super.code]);
}


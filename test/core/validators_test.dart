import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/utils/validators.dart';

void main() {
  group('Validators Tests', () {
    test('validateMerchantName', () {
      expect(Validators.validateMerchantName(null), isNotNull);
      expect(Validators.validateMerchantName(''), isNotNull);
      expect(Validators.validateMerchantName('  '), isNotNull);
      expect(Validators.validateMerchantName('A'), isNotNull); // < 2 chars
      expect(Validators.validateMerchantName('Sharma Kirana'), isNull);
    });

    test('validateUpiVpa', () {
      expect(Validators.validateUpiVpa(null), isNotNull);
      expect(Validators.validateUpiVpa(''), isNotNull);
      expect(Validators.validateUpiVpa('sharmakirana'), isNotNull); // missing @
      expect(Validators.validateUpiVpa('@upi'), isNotNull); // missing username
      expect(Validators.validateUpiVpa('sharma@'), isNotNull); // missing handle
      expect(Validators.validateUpiVpa('sharma@upi'), isNull);
      expect(Validators.validateUpiVpa('9876543210@paytm'), isNull);
      expect(Validators.validateUpiVpa('merchant.store-1@okhdfcbank'), isNull);
    });

    test('validatePhone', () {
      expect(Validators.validatePhone(null), isNull); // Optional
      expect(Validators.validatePhone(''), isNull); // Optional
      expect(Validators.validatePhone('12345'), isNotNull); // Invalid digits
      expect(Validators.validatePhone('5876543210'), isNotNull); // Does not start with 6-9
      expect(Validators.validatePhone('9876543210'), isNull);
      expect(Validators.validatePhone('+91 9876543210'), isNull);
      expect(Validators.validatePhone('919876543210'), isNull);
    });

    test('validatePurchaseAmount', () {
      expect(Validators.validatePurchaseAmount(null), isNotNull);
      expect(Validators.validatePurchaseAmount(''), isNotNull);
      expect(Validators.validatePurchaseAmount('0'), isNotNull);
      expect(Validators.validatePurchaseAmount('-10'), isNotNull);
      expect(Validators.validatePurchaseAmount('abc'), isNotNull);
      expect(Validators.validatePurchaseAmount('120'), isNull);
      expect(Validators.validatePurchaseAmount('770.50'), isNull);
      expect(Validators.validatePurchaseAmount('₹450'), isNull);
    });

    test('validatePurchaseNote', () {
      expect(Validators.validatePurchaseNote(null), isNotNull);
      expect(Validators.validatePurchaseNote(''), isNotNull);
      expect(Validators.validatePurchaseNote('Bread & Eggs'), isNull);
    });
  });
}

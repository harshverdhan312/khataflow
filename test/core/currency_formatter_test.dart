import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter Tests (Integer-Safe Arithmetic)', () {
    group('formatPaise', () {
      test('formats zero paise correctly', () {
        expect(CurrencyFormatter.formatPaise(0), equals('₹0'));
        expect(CurrencyFormatter.formatPaise(0, hideZeroDecimals: false), equals('₹0.00'));
      });

      test('formats 50 paise to ₹0.50', () {
        expect(CurrencyFormatter.formatPaise(50), equals('₹0.50'));
        expect(CurrencyFormatter.formatPaise(50, hideZeroDecimals: false), equals('₹0.50'));
      });

      test('formats 100 paise to ₹1 (or ₹1.00 when hideZeroDecimals is false)', () {
        expect(CurrencyFormatter.formatPaise(100), equals('₹1'));
        expect(CurrencyFormatter.formatPaise(100, hideZeroDecimals: false), equals('₹1.00'));
      });

      test('formats 10050 paise to ₹100.50', () {
        expect(CurrencyFormatter.formatPaise(10050), equals('₹100.50'));
        expect(CurrencyFormatter.formatPaise(10050, hideZeroDecimals: false), equals('₹100.50'));
      });

      test('formats 999999 paise to ₹9,999.99 with Indian numbering format', () {
        expect(CurrencyFormatter.formatPaise(999999), equals('₹9,999.99'));
      });

      test('formats 10000000 paise (1 lakh) to ₹1,00,000', () {
        expect(CurrencyFormatter.formatPaise(10000000), equals('₹1,00,000'));
      });

      test('formats negative paise correctly', () {
        expect(CurrencyFormatter.formatPaise(-5000), equals('-₹50'));
        expect(CurrencyFormatter.formatPaise(-5050), equals('-₹50.50'));
      });
    });

    group('paiseToUpiAmount', () {
      test('converts paise to UPI decimal string without floating point inaccuracies', () {
        expect(CurrencyFormatter.paiseToUpiAmount(0), equals('0.00'));
        expect(CurrencyFormatter.paiseToUpiAmount(50), equals('0.50'));
        expect(CurrencyFormatter.paiseToUpiAmount(100), equals('1.00'));
        expect(CurrencyFormatter.paiseToUpiAmount(10050), equals('100.50'));
        expect(CurrencyFormatter.paiseToUpiAmount(999999), equals('9999.99'));
      });
    });

    group('rupeesToPaise', () {
      test('converts integer rupees to paise', () {
        expect(CurrencyFormatter.rupeesToPaise(1), equals(100));
        expect(CurrencyFormatter.rupeesToPaise(250), equals(25000));
        expect(CurrencyFormatter.rupeesToPaise(0), equals(0));
      });
    });

    group('parseInputToPaise', () {
      test('parses whole rupee strings correctly', () {
        expect(CurrencyFormatter.parseInputToPaise('100'), equals(10000));
        expect(CurrencyFormatter.parseInputToPaise('₹100'), equals(10000));
        expect(CurrencyFormatter.parseInputToPaise(' 1,000 '), equals(100000));
      });

      test('parses decimal rupee strings correctly without float precision loss', () {
        expect(CurrencyFormatter.parseInputToPaise('0.50'), equals(50));
        expect(CurrencyFormatter.parseInputToPaise('0.5'), equals(50));
        expect(CurrencyFormatter.parseInputToPaise('100.50'), equals(10050));
        expect(CurrencyFormatter.parseInputToPaise('9999.99'), equals(999999));
        expect(CurrencyFormatter.parseInputToPaise('₹29.99'), equals(2999));
      });

      test('throws FormatException on invalid or zero amounts', () {
        expect(() => CurrencyFormatter.parseInputToPaise(''), throwsA(isA<FormatException>()));
        expect(() => CurrencyFormatter.parseInputToPaise('0'), throwsA(isA<FormatException>()));
        expect(() => CurrencyFormatter.parseInputToPaise('0.00'), throwsA(isA<FormatException>()));
        expect(() => CurrencyFormatter.parseInputToPaise('-50'), throwsA(isA<FormatException>()));
        expect(() => CurrencyFormatter.parseInputToPaise('abc'), throwsA(isA<FormatException>()));
        expect(() => CurrencyFormatter.parseInputToPaise('10.999'), throwsA(isA<FormatException>()));
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/services/upi_service.dart';
import 'package:khata_flow/core/services/url_launcher_upi_service.dart';

void main() {
  group('UrlLauncherUpiService', () {
    const service = UrlLauncherUpiService();

    group('VPA validation', () {
      test('accepts valid standard UPI VPAs', () {
        expect(service.isValidVpa('merchant@oksbi'), isTrue);
        expect(service.isValidVpa('store.name@paytm'), isTrue);
        expect(service.isValidVpa('9876543210@ybl'), isTrue);
        expect(service.isValidVpa('business_user-1@icici'), isTrue);
      });

      test('rejects invalid UPI VPAs', () {
        expect(service.isValidVpa(''), isFalse);
        expect(service.isValidVpa('   '), isFalse);
        expect(service.isValidVpa('invalid-vpa-without-at'), isFalse);
        expect(service.isValidVpa('@oksbi'), isFalse);
        expect(service.isValidVpa('merchant@'), isFalse);
        expect(service.isValidVpa('merchant@b'), isFalse); // psp handle too short
      });
    });

    group('Paise to Rupee conversion and UPI URI generation', () {
      test('converts 100 paise to 1.00 rupees', () {
        final uri = service.buildUpiUri(
          vpa: 'kirana@upi',
          merchantName: 'Kirana Store',
          amountPaise: 100,
          transactionNote: 'Settlement_via_App',
        );

        expect(uri.queryParameters['am'], equals('1.00'));
        expect(uri.queryParameters['pa'], equals('kirana@upi'));
        expect(uri.queryParameters['pn'], equals('Kirana Store'));
        expect(uri.queryParameters['cu'], equals('INR'));
        expect(uri.queryParameters['tn'], equals('Settlement_via_App'));
      });

      test('converts 50 paise to 0.50 rupees correctly without floating point errors', () {
        final uri = service.buildUpiUri(
          vpa: 'kirana@upi',
          merchantName: 'Kirana Store',
          amountPaise: 50,
          transactionNote: 'Settlement',
        );

        expect(uri.queryParameters['am'], equals('0.50'));
      });

      test('converts 10050 paise to 100.50 rupees', () {
        final uri = service.buildUpiUri(
          vpa: 'kirana@upi',
          merchantName: 'Kirana Store',
          amountPaise: 10050,
          transactionNote: 'Settlement',
        );

        expect(uri.queryParameters['am'], equals('100.50'));
      });

      test('converts 999999 paise to 9999.99 rupees', () {
        final uri = service.buildUpiUri(
          vpa: 'kirana@upi',
          merchantName: 'Kirana Store',
          amountPaise: 999999,
          transactionNote: 'Settlement',
        );

        expect(uri.queryParameters['am'], equals('9999.99'));
      });

      test('properly percent-encodes special characters in merchant name and note', () {
        final uri = service.buildUpiUri(
          vpa: 'kirana@upi',
          merchantName: 'Shree Ganesh & Sons (General Store)',
          amountPaise: 25000,
          transactionNote: 'Settlement for 15% discount & items',
        );

        expect(uri.scheme, equals('upi'));
        expect(uri.host, equals('pay'));
        expect(uri.queryParameters['pn'], equals('Shree Ganesh & Sons (General Store)'));
        expect(uri.queryParameters['tn'], equals('Settlement for 15% discount & items'));
        // Verify toString URL contains encoded query
        expect(uri.toString(), contains('upi://pay?'));
        expect(uri.toString(), contains('cu=INR'));
      });
    });

    group('Launch validation', () {
      test('returns launchFailed on invalid VPA', () async {
        final result = await service.launchPayment(
          vpa: 'invalid-vpa',
          merchantName: 'Store',
          amountPaise: 1000,
          transactionNote: 'Test',
        );

        expect(result.status, equals(UpiLaunchStatus.launchFailed));
        expect(result.statusMessage, contains('Invalid UPI VPA address'));
      });

      test('returns launchFailed on zero or negative amount', () async {
        final zeroResult = await service.launchPayment(
          vpa: 'merchant@upi',
          merchantName: 'Store',
          amountPaise: 0,
          transactionNote: 'Test',
        );

        expect(zeroResult.status, equals(UpiLaunchStatus.launchFailed));
        expect(zeroResult.statusMessage, contains('greater than zero'));

        final negativeResult = await service.launchPayment(
          vpa: 'merchant@upi',
          merchantName: 'Store',
          amountPaise: -500,
          transactionNote: 'Test',
        );

        expect(negativeResult.status, equals(UpiLaunchStatus.launchFailed));
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:khata_flow/core/utils/currency_formatter.dart';
import 'package:khata_flow/features/receipt/domain/settlement_receipt.dart';
import 'package:khata_flow/features/receipt/domain/settlement_statement_formatter.dart';

void main() {
  group('SettlementStatementFormatter Unit Tests', () {
    final testDate = DateTime(2026, 9, 10, 14, 15);
    final expectedDateStr = DateFormat('dd MMM yyyy, hh:mm a').format(testDate);

    test('generates full itemized statement with UTR and Transaction ID', () {
      final receipt = SettlementReceipt(
        settlementId: 'settlement-101',
        merchantId: 'merchant-202',
        merchantName: 'Sharma General Store',
        merchantUpiVpa: 'sharma@upi',
        amountPaise: 60000, // ₹600.00
        status: 'SETTLED',
        settlementDate: testDate,
        utr: 'UTR4455667788',
        transactionId: 'TXN9988776655',
        items: [
          ReceiptPurchaseItem(
            purchaseId: 'p-1',
            note: 'Milk',
            amountPaise: 10000, // ₹100.00
            purchaseDate: DateTime(2026, 9, 8),
          ),
          ReceiptPurchaseItem(
            purchaseId: 'p-2',
            note: 'Groceries',
            amountPaise: 20000, // ₹200.00
            purchaseDate: DateTime(2026, 9, 9),
          ),
          ReceiptPurchaseItem(
            purchaseId: 'p-3',
            note: 'Laundry',
            amountPaise: 30000, // ₹300.00
            purchaseDate: DateTime(2026, 9, 10),
          ),
        ],
        totalSettledPaise: 60000,
      );

      final statement = SettlementStatementFormatter.format(receipt);

      expect(statement, contains('KhataFlow Settlement Statement'));
      expect(statement, contains('Paid to: Sharma General Store'));
      expect(statement, contains('UPI ID: sharma@upi'));
      expect(statement, contains('Amount Settled: ${CurrencyFormatter.formatPaise(60000)}'));
      expect(statement, contains('Date: $expectedDateStr'));
      expect(statement, contains('Items Settled'));
      expect(statement, contains('Milk: ${CurrencyFormatter.formatPaise(10000)}'));
      expect(statement, contains('Groceries: ${CurrencyFormatter.formatPaise(20000)}'));
      expect(statement, contains('Laundry: ${CurrencyFormatter.formatPaise(30000)}'));
      expect(statement, contains('Total Settled: ${CurrencyFormatter.formatPaise(60000)}'));
      expect(statement, contains('Payment Reference: UTR4455667788'));
      expect(statement, contains('Transaction ID: TXN9988776655'));
      expect(
        statement,
        contains('This is a local ledger record. KhataFlow does not hold or process funds.'),
      );
    });

    test('omits UTR and Transaction ID when absent', () {
      final receipt = SettlementReceipt(
        settlementId: 'settlement-102',
        merchantId: 'merchant-202',
        merchantName: 'Gupta Sweets',
        merchantUpiVpa: 'gupta@upi',
        amountPaise: 25000,
        status: 'SETTLED',
        settlementDate: testDate,
        items: [
          ReceiptPurchaseItem(
            purchaseId: 'p-4',
            note: 'Sweets Box',
            amountPaise: 25000,
            purchaseDate: DateTime(2026, 9, 10),
          ),
        ],
        totalSettledPaise: 25000,
      );

      final statement = SettlementStatementFormatter.format(receipt);

      expect(statement, contains('Paid to: Gupta Sweets'));
      expect(statement, contains('UPI ID: gupta@upi'));
      expect(statement, contains('Amount Settled: ${CurrencyFormatter.formatPaise(25000)}'));
      expect(statement, contains('Sweets Box: ${CurrencyFormatter.formatPaise(25000)}'));
      expect(statement, isNot(contains('Payment Reference:')));
      expect(statement, isNot(contains('Transaction ID:')));
    });

    test('handles empty linked items gracefully without crashing', () {
      final receipt = SettlementReceipt(
        settlementId: 'settlement-103',
        merchantId: 'merchant-202',
        merchantName: 'Quick Corner Store',
        merchantUpiVpa: 'quick@upi',
        amountPaise: 15000,
        status: 'SETTLED',
        settlementDate: testDate,
        items: [],
        totalSettledPaise: 15000,
      );

      final statement = SettlementStatementFormatter.format(receipt);

      expect(statement, contains('Paid to: Quick Corner Store'));
      expect(statement, contains('Direct settlement with merchant'));
      expect(statement, contains('Total Settled: ${CurrencyFormatter.formatPaise(15000)}'));
    });

    test('omits UPI ID line when merchant UPI VPA is empty', () {
      final receipt = SettlementReceipt(
        settlementId: 'settlement-104',
        merchantId: 'merchant-202',
        merchantName: 'Cash Store',
        merchantUpiVpa: '',
        amountPaise: 5000,
        status: 'SETTLED',
        settlementDate: testDate,
        items: [],
        totalSettledPaise: 5000,
      );

      final statement = SettlementStatementFormatter.format(receipt);

      expect(statement, contains('Paid to: Cash Store'));
      expect(statement, isNot(contains('UPI ID:')));
    });
  });
}

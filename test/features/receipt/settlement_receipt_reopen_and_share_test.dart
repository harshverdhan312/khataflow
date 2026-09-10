import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/services/receipt_share_service.dart';
import 'package:khata_flow/core/services/settlement_pdf_service.dart';
import 'package:khata_flow/features/receipt/domain/settlement_receipt.dart';
import 'package:khata_flow/features/receipt/presentation/receipt_providers.dart';
import 'package:khata_flow/features/receipt/presentation/settlement_receipt_screen.dart';

class MockReceiptShareService implements ReceiptShareService {
  String? sharedText;
  String? sharedSubject;
  String? sharedFilePath;
  String? sharedMimeType;

  @override
  Future<void> shareGenericText({
    required String text,
    String? subject,
  }) async {
    sharedText = text;
    sharedSubject = subject;
  }

  @override
  Future<void> shareFile({
    required String filePath,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    sharedFilePath = filePath;
    sharedMimeType = mimeType;
    sharedSubject = subject;
    sharedText = text;
  }

  @override
  Future<void> shareWhatsAppReceipt({
    required String phone,
    required String message,
  }) async {}
}

class MockSettlementPdfService implements SettlementPdfService {
  SettlementReceipt? capturedReceipt;

  @override
  Future<Uint8List> generatePdfBytes(SettlementReceipt receipt) async {
    capturedReceipt = receipt;
    return Uint8List.fromList([37, 80, 68, 70, 45]);
  }

  @override
  Future<File> generateAndSavePdf(SettlementReceipt receipt) async {
    capturedReceipt = receipt;
    return File('/tmp/test_statement.pdf');
  }
}

void main() {
  final testDate = DateTime(2026, 9, 10, 14, 30);

  final settledReceipt = SettlementReceipt(
    settlementId: 's_reopen_1',
    merchantId: 'm_1',
    merchantName: 'Sharma General Store',
    merchantUpiVpa: 'sharma@upi',
    amountPaise: 60000,
    status: 'SETTLED',
    settlementDate: testDate,
    utr: 'UTR1234567890',
    transactionId: 'TXN12345',
    items: [
      ReceiptPurchaseItem(
        purchaseId: 'p_1',
        note: 'Milk & Bread',
        amountPaise: 60000,
        purchaseDate: testDate,
      ),
    ],
    totalSettledPaise: 60000,
  );

  group('Settlement Receipt Reopen and Sharing Tests', () {
    testWidgets('SETTLED settlement reopens receipt and displays canonical details', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settlementReceiptProvider('s_reopen_1').overrideWith(
              (ref) async => settledReceipt,
            ),
          ],
          child: const MaterialApp(
            home: SettlementReceiptScreen(settlementId: 's_reopen_1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Settlement Receipt'), findsOneWidget);
      expect(find.text('Payment Settled'), findsOneWidget);
      expect(find.text('Sharma General Store'), findsOneWidget);
      expect(find.text('sharma@upi'), findsWidgets);
      expect(find.text('₹600'), findsWidgets);
      expect(find.text('UTR1234567890'), findsOneWidget);
      expect(find.text('TXN12345'), findsOneWidget);
      expect(find.text('Milk & Bread'), findsOneWidget);
      expect(find.text('Share Text'), findsOneWidget);
      expect(find.text('Share PDF'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Share Text and Share PDF actions work properly after reopening receipt', (tester) async {
      final mockShareService = MockReceiptShareService();
      final mockPdfService = MockSettlementPdfService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settlementReceiptProvider('s_reopen_1').overrideWith(
              (ref) async => settledReceipt,
            ),
            receiptShareServiceProvider.overrideWithValue(mockShareService),
            settlementPdfServiceProvider.overrideWithValue(mockPdfService),
          ],
          child: const MaterialApp(
            home: SettlementReceiptScreen(settlementId: 's_reopen_1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll down and Tap Share Text
      await tester.scrollUntilVisible(find.text('Share Text'), 100);
      await tester.tap(find.text('Share Text'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockShareService.sharedText, isNotNull);
      expect(mockShareService.sharedText, contains('Sharma General Store'));
      expect(mockShareService.sharedText, contains('sharma@upi'));
      expect(mockShareService.sharedText, contains('₹600'));

      // Tap Share PDF
      await tester.scrollUntilVisible(find.text('Share PDF'), 100);
      await tester.tap(find.text('Share PDF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockPdfService.capturedReceipt?.settlementId, equals('s_reopen_1'));
      expect(mockShareService.sharedFilePath, equals('/tmp/test_statement.pdf'));
    });

    testWidgets('Non-SETTLED settlement shows error state instead of normal receipt', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settlementReceiptProvider('s_failed_1').overrideWith(
              (ref) async => null, // Non-SETTLED returns null from repository
            ),
          ],
          child: const MaterialApp(
            home: SettlementReceiptScreen(settlementId: 's_failed_1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Receipt Not Available'), findsOneWidget);
      expect(find.text('Share Text'), findsNothing);
      expect(find.text('Share PDF'), findsNothing);
    });
  });
}

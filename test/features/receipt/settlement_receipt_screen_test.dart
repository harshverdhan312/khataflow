import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/services/receipt_share_service.dart';
import 'package:khata_flow/core/services/settlement_pdf_service.dart';
import 'package:khata_flow/core/utils/currency_formatter.dart';
import 'package:khata_flow/features/receipt/domain/settlement_receipt.dart';
import 'package:khata_flow/features/receipt/presentation/receipt_providers.dart';
import 'package:khata_flow/features/receipt/presentation/settlement_receipt_screen.dart';

void main() {
  final testDate = DateTime(2026, 9, 10, 14, 30);

  final testReceiptWithMetadata = SettlementReceipt(
    settlementId: 'settlement-101',
    merchantId: 'merchant-202',
    merchantName: 'Sharma Grocery Store',
    merchantUpiVpa: 'sharma@oksbi',
    amountPaise: 185000, // ₹1,850.00
    status: 'SETTLED',
    settlementDate: testDate,
    utr: 'UTR9988776655',
    transactionId: 'TXN1122334455',
    items: [
      ReceiptPurchaseItem(
        purchaseId: 'p-1',
        note: 'Wheat Flour & Sugar',
        amountPaise: 100000,
        purchaseDate: DateTime(2026, 9, 8),
        category: 'Grocery',
      ),
      ReceiptPurchaseItem(
        purchaseId: 'p-2',
        note: 'Cooking Oil',
        amountPaise: 85000,
        purchaseDate: DateTime(2026, 9, 9),
        category: 'Grocery',
      ),
    ],
    totalSettledPaise: 185000,
  );

  final testReceiptWithoutMetadata = SettlementReceipt(
    settlementId: 'settlement-102',
    merchantId: 'merchant-202',
    merchantName: 'Sharma Grocery Store',
    merchantUpiVpa: 'sharma@oksbi',
    amountPaise: 50000,
    status: 'SETTLED',
    settlementDate: testDate,
    items: [
      ReceiptPurchaseItem(
        purchaseId: 'p-3',
        note: 'Snacks',
        amountPaise: 50000,
        purchaseDate: DateTime(2026, 9, 10),
      ),
    ],
    totalSettledPaise: 50000,
  );

  final testReceiptLongAndLarge = SettlementReceipt(
    settlementId: 'settlement-103',
    merchantId: 'merchant-long',
    merchantName: 'Shri Venkateshwara Provision & Agricultural Wholesale Superstore Private Limited',
    merchantUpiVpa: 'venkateshwara.wholesale.enterprise@hdfcbank',
    amountPaise: 999999900, // ₹99,99,999.00
    status: 'SETTLED',
    settlementDate: testDate,
    utr: 'UTR999999999999',
    transactionId: 'TXN888888888888',
    items: [
      ReceiptPurchaseItem(
        purchaseId: 'p-long-1',
        note: '50kg Organic Wheat Bags from Punjab Warehouse, Batch 2026-A1 with Extra Jute Packing',
        amountPaise: 500000000,
        purchaseDate: DateTime(2026, 9, 1),
      ),
      ReceiptPurchaseItem(
        purchaseId: 'p-long-2',
        note: 'Refined Mustard Oil Tin Pack 15 Liters x 20 Units Wholesale Order',
        amountPaise: 499999900,
        purchaseDate: DateTime(2026, 9, 2),
      ),
    ],
    totalSettledPaise: 999999900,
  );

  Widget createWidgetUnderTest({
    required String settlementId,
    SettlementReceipt? receiptToReturn,
    bool returnError = false,
    ReceiptShareService? shareService,
    SettlementPdfService? pdfService,
  }) {
    return ProviderScope(
      overrides: [
        settlementReceiptProvider(settlementId).overrideWith((ref) async {
          if (returnError) {
            throw Exception('Database failure');
          }
          return receiptToReturn;
        }),
        if (shareService != null)
          receiptShareServiceProvider.overrideWithValue(shareService),
        if (pdfService != null)
          settlementPdfServiceProvider.overrideWithValue(pdfService),
      ],
      child: MaterialApp(
        home: SettlementReceiptScreen(settlementId: settlementId),
      ),
    );
  }

  group('SettlementReceiptScreen Widget Tests', () {
    testWidgets('renders full receipt details with items, total, and metadata', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          settlementId: 'settlement-101',
          receiptToReturn: testReceiptWithMetadata,
        ),
      );
      await tester.pumpAndSettle();

      // Header and amount
      expect(find.text('Settlement Receipt'), findsOneWidget);
      expect(find.text('Payment Settled'), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatPaise(185000)), findsWidgets);

      // Merchant information
      expect(find.text('Paid to'), findsOneWidget);
      expect(find.text('Sharma Grocery Store'), findsOneWidget);
      expect(find.text('sharma@oksbi'), findsWidgets);

      // Metadata
      expect(find.text('Payment Reference (UTR)'), findsOneWidget);
      expect(find.text('UTR9988776655'), findsOneWidget);
      expect(find.text('Transaction ID'), findsOneWidget);
      expect(find.text('TXN1122334455'), findsOneWidget);

      // Items Settled
      expect(find.text('Items Settled'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('Wheat Flour & Sugar'), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatPaise(100000)), findsOneWidget);
      expect(find.text('Cooking Oil'), findsOneWidget);
      expect(find.text(CurrencyFormatter.formatPaise(85000)), findsOneWidget);

      // Total row
      expect(find.text('Total Settled'), findsOneWidget);

      // Actions
      expect(find.text('Share Text'), findsOneWidget);
      expect(find.text('Share PDF'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('handles long merchant name, long notes, and large amount without overflow', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          settlementId: 'settlement-103',
          receiptToReturn: testReceiptLongAndLarge,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.formatPaise(999999900)), findsWidgets);
      expect(
        find.text('Shri Venkateshwara Provision & Agricultural Wholesale Superstore Private Limited'),
        findsOneWidget,
      );
      expect(
        find.text('50kg Organic Wheat Bags from Punjab Warehouse, Batch 2026-A1 with Extra Jute Packing'),
        findsOneWidget,
      );
      expect(
        find.text('Refined Mustard Oil Tin Pack 15 Liters x 20 Units Wholesale Order'),
        findsOneWidget,
      );
      // No layout exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('omits UTR and Transaction ID rows when they are absent', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          settlementId: 'settlement-102',
          receiptToReturn: testReceiptWithoutMetadata,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.formatPaise(50000)), findsWidgets);
      expect(find.text('Sharma Grocery Store'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);

      // Ensure optional metadata fields are not displayed
      expect(find.text('Payment Reference (UTR)'), findsNothing);
      expect(find.text('Transaction ID'), findsNothing);
    });

    testWidgets('renders Receipt Not Available view when receipt is null (e.g. not settled)', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          settlementId: 'settlement-unsettled',
          receiptToReturn: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Receipt Not Available'), findsOneWidget);
      expect(
        find.text('Receipts are only generated for successfully settled payments.'),
        findsOneWidget,
      );

      expect(find.text('Go Back'), findsOneWidget);
    });

    testWidgets('renders error view when repository throws an exception', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          settlementId: 'settlement-error',
          returnError: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Error loading receipt:'), findsOneWidget);
    });

    testWidgets('tapping Share Statement triggers share service with formatted statement', (tester) async {
      final mockShareService = MockReceiptShareService();

      await tester.pumpWidget(
        createWidgetUnderTest(
          settlementId: 'settlement-101',
          receiptToReturn: testReceiptWithMetadata,
          shareService: mockShareService,
        ),
      );
      await tester.pumpAndSettle();

      // Tap AppBar share button
      expect(find.byIcon(Icons.share_rounded), findsWidgets);
      await tester.tap(find.byTooltip('Share Statement'));
      await tester.pumpAndSettle();

      expect(mockShareService.shareGenericTextCalled, isTrue);
      expect(mockShareService.lastSharedText, contains('KhataFlow Settlement Statement'));
      expect(mockShareService.lastSharedText, contains('Paid to: Sharma Grocery Store'));
      expect(mockShareService.lastSharedText, contains('Wheat Flour & Sugar'));
      expect(mockShareService.lastSubject, contains('Sharma Grocery Store'));
    });

    testWidgets('shows error SnackBar when share statement service throws', (tester) async {
      final mockShareService = MockReceiptShareService(shouldThrow: true);

      await tester.pumpWidget(
        createWidgetUnderTest(
          settlementId: 'settlement-101',
          receiptToReturn: testReceiptWithMetadata,
          shareService: mockShareService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Share Statement'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to share statement:'), findsOneWidget);
      // Receipt remains intact and visible
      expect(find.text('Payment Settled'), findsOneWidget);
    });

    testWidgets('tapping bottom Share Text button triggers statement sharing', (tester) async {
      final mockShareService = MockReceiptShareService();

      await tester.pumpWidget(
        createWidgetUnderTest(
          settlementId: 'settlement-101',
          receiptToReturn: testReceiptWithMetadata,
          shareService: mockShareService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Share Text'), 100);
      await tester.tap(find.text('Share Text'));
      await tester.pumpAndSettle();

      expect(mockShareService.shareGenericTextCalled, isTrue);
    });

    testWidgets('tapping Share PDF triggers PDF generation and file sharing', (tester) async {
      final mockShareService = MockReceiptShareService();
      final mockPdfService = MockSettlementPdfService();

      await tester.pumpWidget(
        createWidgetUnderTest(
          settlementId: 'settlement-101',
          receiptToReturn: testReceiptWithMetadata,
          shareService: mockShareService,
          pdfService: mockPdfService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Share PDF'), 100);
      await tester.tap(find.text('Share PDF'));
      await tester.pumpAndSettle();

      expect(mockPdfService.generateAndSavePdfCalled, isTrue);
      expect(mockShareService.shareFileCalled, isTrue);
      expect(mockShareService.lastSharedFilePath, equals('/tmp/test_statement.pdf'));
      expect(mockShareService.lastMimeType, equals('application/pdf'));
      expect(mockShareService.lastSubject, contains('Sharma Grocery Store'));
    });

    testWidgets('prevents double-tap race conditions when PDF sharing is in progress', (tester) async {
      final completer = Completer<File>();
      final mockPdfService = MockSettlementPdfService(customCompleter: completer);
      final mockShareService = MockReceiptShareService();

      await tester.pumpWidget(
        createWidgetUnderTest(
          settlementId: 'settlement-101',
          receiptToReturn: testReceiptWithMetadata,
          shareService: mockShareService,
          pdfService: mockPdfService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Share PDF'), 100);
      await tester.tap(find.text('Share PDF'));
      await tester.pump(); // Start async work without settling

      // Button is now in loading state
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Attempt second tap while loading
      await tester.tap(find.text('Share PDF'));
      await tester.pump();

      // Complete the pending PDF generation
      completer.complete(File('/tmp/test_statement.pdf'));
      await tester.pumpAndSettle();

      // Ensure generateAndSavePdf was called exactly once
      expect(mockPdfService.callCount, equals(1));
    });

    testWidgets('shows error SnackBar when PDF generation throws', (tester) async {
      final mockShareService = MockReceiptShareService();
      final mockPdfService = MockSettlementPdfService(shouldThrow: true);

      await tester.pumpWidget(
        createWidgetUnderTest(
          settlementId: 'settlement-101',
          receiptToReturn: testReceiptWithMetadata,
          shareService: mockShareService,
          pdfService: mockPdfService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Share PDF'), 100);
      await tester.tap(find.text('Share PDF'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to generate or share PDF:'), findsOneWidget);
    });
  });
}

class MockReceiptShareService implements ReceiptShareService {
  final bool shouldThrow;
  bool shareGenericTextCalled = false;
  bool shareFileCalled = false;
  String? lastSharedText;
  String? lastSubject;
  String? lastSharedFilePath;
  String? lastMimeType;

  MockReceiptShareService({this.shouldThrow = false});

  @override
  Future<void> shareGenericText({required String text, String? subject}) async {
    if (shouldThrow) {
      throw Exception('Native share intent unavailable');
    }
    shareGenericTextCalled = true;
    lastSharedText = text;
    lastSubject = subject;
  }

  @override
  Future<void> shareWhatsAppReceipt({required String phone, required String message}) async {
    await shareGenericText(text: message);
  }

  @override
  Future<void> shareFile({
    required String filePath,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    if (shouldThrow) {
      throw Exception('Native file share failed');
    }
    shareFileCalled = true;
    lastSharedFilePath = filePath;
    lastMimeType = mimeType;
    lastSubject = subject;
    lastSharedText = text;
  }
}

class MockSettlementPdfService implements SettlementPdfService {
  final bool shouldThrow;
  final Completer<File>? customCompleter;
  bool generateAndSavePdfCalled = false;
  int callCount = 0;

  MockSettlementPdfService({this.shouldThrow = false, this.customCompleter});

  @override
  Future<Uint8List> generatePdfBytes(SettlementReceipt receipt) async {
    if (shouldThrow) {
      throw StateError('Cannot generate PDF');
    }
    return Uint8List.fromList([37, 80, 68, 70, 45]);
  }

  @override
  Future<File> generateAndSavePdf(SettlementReceipt receipt) async {
    callCount++;
    if (shouldThrow) {
      throw StateError('Cannot generate PDF');
    }
    generateAndSavePdfCalled = true;
    if (customCompleter != null) {
      return customCompleter!.future;
    }
    return File('/tmp/test_statement.pdf');
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/services/settlement_pdf_service_impl.dart';
import 'package:khata_flow/features/receipt/domain/settlement_receipt.dart';

String extractAllPdfContent(Uint8List pdfBytes) {
  final buffer = StringBuffer();
  // Include raw uncompressed PDF structures
  buffer.writeln(String.fromCharCodes(pdfBytes));

  // Extract and decompress all FlateDecode streams
  final streamMarker = Uint8List.fromList('stream\n'.codeUnits);
  final endStreamMarker = Uint8List.fromList('\nendstream'.codeUnits);

  int currentIndex = 0;
  while (true) {
    final streamStart = _findSublist(pdfBytes, streamMarker, currentIndex);
    if (streamStart == -1) break;
    final contentStart = streamStart + streamMarker.length;
    final streamEnd = _findSublist(pdfBytes, endStreamMarker, contentStart);
    if (streamEnd == -1) break;

    final compressedBytes = pdfBytes.sublist(contentStart, streamEnd);
    try {
      final decompressed = zlib.decode(compressedBytes);
      buffer.writeln(String.fromCharCodes(decompressed));
    } catch (_) {
      buffer.writeln(String.fromCharCodes(compressedBytes));
    }

    currentIndex = streamEnd + endStreamMarker.length;
  }

  return buffer.toString();
}

String extractReadableTextFromPdf(Uint8List pdfBytes) {
  final content = extractAllPdfContent(pdfBytes);
  final regExp = RegExp(r'\((.*?)\)');
  final matches = regExp.allMatches(content);
  return matches.map((m) => m.group(1) ?? '').join(' ');
}

int _findSublist(Uint8List source, Uint8List pattern, int start) {
  if (pattern.isEmpty || start + pattern.length > source.length) return -1;
  for (int i = start; i <= source.length - pattern.length; i++) {
    bool match = true;
    for (int j = 0; j < pattern.length; j++) {
      if (source[i + j] != pattern[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = SettlementPdfServiceImpl(
    getTemporaryDirectoryOverride: () async => Directory.systemTemp,
  );
  final testDate = DateTime(2026, 9, 10, 14, 15);

  final settledReceiptWithAllMetadata = SettlementReceipt(
    settlementId: 'settlement-101',
    merchantId: 'merchant-202',
    merchantName: 'Sharma General Store',
    merchantUpiVpa: 'sharma@oksbi',
    amountPaise: 60000, // Rs. 600.00
    status: 'SETTLED',
    settlementDate: testDate,
    utr: 'UTR9988776655',
    transactionId: 'TXN1122334455',
    items: [
      ReceiptPurchaseItem(
        purchaseId: 'p-1',
        note: 'Wheat Flour',
        amountPaise: 10000, // Rs. 100.00
        purchaseDate: DateTime(2026, 9, 8),
        category: 'Grocery',
      ),
      ReceiptPurchaseItem(
        purchaseId: 'p-2',
        note: 'Cooking Oil',
        amountPaise: 20000, // Rs. 200.00
        purchaseDate: DateTime(2026, 9, 9),
        category: 'Grocery',
      ),
      ReceiptPurchaseItem(
        purchaseId: 'p-3',
        note: 'Laundry Soap',
        amountPaise: 30000, // Rs. 300.00
        purchaseDate: DateTime(2026, 9, 10),
      ),
    ],
    totalSettledPaise: 60000,
  );

  final settledReceiptWithoutMetadata = SettlementReceipt(
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

  final settledReceiptLongAndLarge = SettlementReceipt(
    settlementId: 'settlement-long-large',
    merchantId: 'merchant-wholesale',
    merchantName: 'Shri Venkateshwara Provision & Agricultural Wholesale Superstore Private Limited',
    merchantUpiVpa: 'venkateshwara.wholesale.enterprise@hdfcbank',
    amountPaise: 999999900, // Rs. 99,99,999.00
    status: 'SETTLED',
    settlementDate: testDate,
    utr: 'UTR999999999999',
    transactionId: 'TXN888888888888',
    items: [
      ReceiptPurchaseItem(
        purchaseId: 'p-long-1',
        note: '50kg Organic Wheat Bags from Punjab Warehouse Batch 2026-A1 Extra Jute Packing',
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

  group('SettlementPdfService - SETTLED-Only Semantics Invariant', () {
    const nonSettledStatuses = [
      'FAILED',
      'UNKNOWN',
      'UPI_LAUNCHED',
      'INITIATED',
      'failed',
      'initiated',
      'pending',
      '',
    ];

    for (final status in nonSettledStatuses) {
      test('rejects status "$status" and throws StateError without generating PDF bytes', () async {
        final invalidReceipt = SettlementReceipt(
          settlementId: 'settlement-invalid-$status',
          merchantId: 'merchant-202',
          merchantName: 'Sharma General Store',
          merchantUpiVpa: 'sharma@upi',
          amountPaise: 50000,
          status: status,
          settlementDate: testDate,
          items: [],
          totalSettledPaise: 50000,
        );

        expect(
          () => service.generatePdfBytes(invalidReceipt),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot generate settlement PDF for a non-SETTLED settlement'),
          )),
        );
      });

      test('rejects status "$status" and throws StateError without creating a file', () async {
        final invalidReceipt = SettlementReceipt(
          settlementId: 'settlement-invalid-$status',
          merchantId: 'merchant-202',
          merchantName: 'Sharma General Store',
          merchantUpiVpa: 'sharma@upi',
          amountPaise: 50000,
          status: status,
          settlementDate: testDate,
          items: [],
          totalSettledPaise: 50000,
        );

        expect(
          () => service.generateAndSavePdf(invalidReceipt),
          throwsA(isA<StateError>()),
        );
      });
    }
  });

  group('SettlementPdfService - PDF Generation & Content Verification', () {
    test('generates valid PDF byte stream with %PDF header for SETTLED receipt', () async {
      final bytes = await service.generatePdfBytes(settledReceiptWithAllMetadata);

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(500));

      final header = String.fromCharCodes(bytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('generates valid PDF for receipt without optional metadata', () async {
      final bytes = await service.generatePdfBytes(settledReceiptWithoutMetadata);

      expect(bytes, isNotEmpty);
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('generates valid PDF for direct settlement (empty items)', () async {
      final directReceipt = SettlementReceipt(
        settlementId: 'settlement-direct',
        merchantId: 'merchant-303',
        merchantName: 'Quick Grocery',
        merchantUpiVpa: 'quick@upi',
        amountPaise: 10000,
        status: 'SETTLED',
        settlementDate: testDate,
        items: [],
        totalSettledPaise: 10000,
      );

      final bytes = await service.generatePdfBytes(directReceipt);
      expect(bytes, isNotEmpty);
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('handles long merchant name, long notes, and large amounts in PDF', () async {
      final bytes = await service.generatePdfBytes(settledReceiptLongAndLarge);
      expect(bytes, isNotEmpty);
      final readableText = extractReadableTextFromPdf(bytes);

      expect(readableText, contains('Shri Venkateshwara Provision & Agricultural Wholesale Superstore'));
      expect(readableText, contains('venkateshwara.wholesale.enterprise@hdfcbank'));
      expect(readableText, contains('99,99,999.00'));
      expect(readableText, contains('50kg Organic Wheat Bags from Punjab Warehouse'));
      expect(readableText, contains('Refined Mustard Oil Tin Pack 15 Liters'));
      expect(readableText, contains('UTR999999999999'));
      expect(readableText, contains('TXN888888888888'));
    });

    test('generates multi-page PDF gracefully for large item lists (30 items)', () async {
      final manyItems = List.generate(
        30,
        (i) => ReceiptPurchaseItem(
          purchaseId: 'p-$i',
          note: 'Bulk Item #$i - Grade A Standard Package',
          amountPaise: (i + 1) * 10000,
          purchaseDate: DateTime(2026, 9, 1).add(Duration(days: i % 10)),
        ),
      );
      final totalPaise = manyItems.fold<int>(0, (sum, it) => sum + it.amountPaise);

      final multiItemReceipt = SettlementReceipt(
        settlementId: 'settlement-many-items',
        merchantId: 'merchant-bulk',
        merchantName: 'Central Wholesale Mart',
        merchantUpiVpa: 'central@mart',
        amountPaise: totalPaise,
        status: 'SETTLED',
        settlementDate: testDate,
        items: manyItems,
        totalSettledPaise: totalPaise,
      );

      final bytes = await service.generatePdfBytes(multiItemReceipt);
      expect(bytes, isNotEmpty);
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, equals('%PDF-'));
    });

    test('generateAndSavePdf saves file to filesystem with sanitized filename', () async {
      final file = await service.generateAndSavePdf(settledReceiptWithAllMetadata);

      expect(await file.exists(), isTrue);
      expect(file.path, contains('KhataFlow_Settlement_Sharma_General_Store_'));
      expect(file.path.endsWith('.pdf'), isTrue);

      final fileBytes = await file.readAsBytes();
      expect(fileBytes.length, greaterThan(500));
      final header = String.fromCharCodes(fileBytes.take(5));
      expect(header, equals('%PDF-'));

      if (await file.exists()) {
        await file.delete();
      }
    });

    test('verifies content elements in generated PDF output beyond file size', () async {
      final bytes = await service.generatePdfBytes(settledReceiptWithAllMetadata);
      final readableText = extractReadableTextFromPdf(bytes);

      // 1. Branding & Header
      expect(readableText, contains('KhataFlow'));
      expect(readableText, contains('Settlement Statement'));
      expect(readableText, contains('Payment Settled'));

      // 2. Merchant Name & UPI ID
      expect(readableText, contains('Sharma General Store'));
      expect(readableText, contains('sharma@oksbi'));

      // 3. Settlement Amount & Total Settled Amount
      expect(readableText, contains('600.00'));

      // 4. Linked Purchase Information
      expect(readableText, contains('Wheat Flour'));
      expect(readableText, contains('Cooking Oil'));
      expect(readableText, contains('Laundry Soap'));
      expect(readableText, contains('100.00'));
      expect(readableText, contains('200.00'));
      expect(readableText, contains('300.00'));

      // 5. Optional UTR & Transaction ID
      expect(readableText, contains('UTR9988776655'));
      expect(readableText, contains('TXN1122334455'));

      // 6. Non-custodial Disclaimer
      expect(readableText, contains('KhataFlow is a personal ledger'));
    });

    test('verifies omitted UTR and Transaction ID in generated PDF when absent', () async {
      final bytes = await service.generatePdfBytes(settledReceiptWithoutMetadata);
      final readableText = extractReadableTextFromPdf(bytes);

      expect(readableText, contains('Gupta Sweets'));
      expect(readableText, contains('gupta@upi'));
      expect(readableText, contains('Sweets Box'));
      expect(readableText, contains('250.00'));
      expect(readableText, isNot(contains('Payment Reference')));
      expect(readableText, isNot(contains('Transaction ID')));
    });
  });
}

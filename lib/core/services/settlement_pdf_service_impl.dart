import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/receipt/domain/settlement_receipt.dart';
import 'settlement_pdf_service.dart';

class SettlementPdfServiceImpl implements SettlementPdfService {
  final Future<Directory> Function()? getTemporaryDirectoryOverride;

  const SettlementPdfServiceImpl({
    this.getTemporaryDirectoryOverride,
  });

  static final NumberFormat _integerGroupFormatter = NumberFormat('#,##,##0', 'en_IN');

  /// Formats integer paise into a clean, print-friendly INR string with standard PDF font compatibility.
  /// (e.g. 60000 -> "Rs. 600.00", 185000 -> "Rs. 1,850.00")
  static String formatCurrencyForPdf(int paise) {
    final bool isNegative = paise < 0;
    final int absPaise = paise.abs();
    final int rupees = absPaise ~/ 100;
    final int paiseRemainder = absPaise % 100;

    final String formattedRupees = _integerGroupFormatter.format(rupees);
    final String prefix = isNegative ? '-Rs. ' : 'Rs. ';
    final String paddedPaise = paiseRemainder.toString().padLeft(2, '0');
    return '$prefix$formattedRupees.$paddedPaise';
  }

  @override
  Future<Uint8List> generatePdfBytes(SettlementReceipt receipt) async {
    // 1. Strict SETTLED-only invariant check
    if (receipt.status.toUpperCase() != 'SETTLED') {
      throw StateError(
        'Cannot generate settlement PDF for a non-SETTLED settlement (status: ${receipt.status}).',
      );
    }

    final pdf = pw.Document();

    final dateFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(receipt.settlementDate);
    final amountFormatted = formatCurrencyForPdf(receipt.amountPaise);
    final totalFormatted = formatCurrencyForPdf(receipt.totalSettledPaise);

    // Styling constants
    final primaryColor = PdfColor.fromHex('1E3A8A'); // Navy
    final successColor = PdfColor.fromHex('16A34A'); // Green
    final textColor = PdfColor.fromHex('0F172A');
    final secondaryTextColor = PdfColor.fromHex('64748B');
    final borderColor = PdfColor.fromHex('E2E8F0');
    final lightBgColor = PdfColor.fromHex('F8FAFC');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: borderColor, thickness: 0.5),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'KhataFlow is a personal ledger. It does not hold, process, or verify funds.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: secondaryTextColor,
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'KhataFlow',
                      style: pw.TextStyle(
                        color: primaryColor,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Settlement Statement',
                      style: pw.TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: lightBgColor,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: successColor, width: 1),
                  ),
                  child: pw.Text(
                    'Payment Settled',
                    style: pw.TextStyle(
                      color: successColor,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: borderColor, thickness: 1),
            pw.SizedBox(height: 14),

            // Summary Info Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Merchant details
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Merchant:',
                        style: pw.TextStyle(color: secondaryTextColor, fontSize: 10),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        receipt.merchantName,
                        style: pw.TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (receipt.merchantUpiVpa.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'UPI ID: ${receipt.merchantUpiVpa}',
                          style: pw.TextStyle(color: secondaryTextColor, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),

                // Settlement summary
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Amount Settled:',
                        style: pw.TextStyle(color: secondaryTextColor, fontSize: 10),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        amountFormatted,
                        style: pw.TextStyle(
                          color: successColor,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date: $dateFormatted',
                        style: pw.TextStyle(color: secondaryTextColor, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Optional Metadata
            if ((receipt.utr != null && receipt.utr!.isNotEmpty) ||
                (receipt.transactionId != null && receipt.transactionId!.isNotEmpty)) ...[
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderColor, width: 0.5),
                ),
                child: pw.Row(
                  children: [
                    if (receipt.utr != null && receipt.utr!.isNotEmpty)
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'Payment Reference: ',
                                style: pw.TextStyle(color: secondaryTextColor, fontSize: 9),
                              ),
                              pw.TextSpan(
                                text: receipt.utr!,
                                style: pw.TextStyle(
                                  color: textColor,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (receipt.transactionId != null && receipt.transactionId!.isNotEmpty)
                      pw.Expanded(
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'Transaction ID: ',
                                style: pw.TextStyle(color: secondaryTextColor, fontSize: 9),
                              ),
                              pw.TextSpan(
                                text: receipt.transactionId!,
                                style: pw.TextStyle(
                                  color: textColor,
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            pw.SizedBox(height: 18),

            // Table Title
            pw.Text(
              'Items Settled',
              style: pw.TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),

            // Items Table
            if (receipt.items.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'Direct settlement with merchant.',
                  style: pw.TextStyle(color: secondaryTextColor, fontSize: 11, fontStyle: pw.FontStyle.italic),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: borderColor, width: 0.5),
                  bottom: pw.BorderSide(color: borderColor, width: 0.5),
                  top: pw.BorderSide(color: borderColor, width: 1),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(4),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBgColor),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Item / Note',
                          style: pw.TextStyle(color: secondaryTextColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Date',
                          style: pw.TextStyle(color: secondaryTextColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Amount',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(color: secondaryTextColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  // Item rows
                  ...receipt.items.map((item) {
                    final itemDate = DateFormat('dd MMM yyyy').format(item.purchaseDate);
                    final itemAmount = formatCurrencyForPdf(item.amountPaise);
                    final itemNote = item.note.isNotEmpty ? item.note : 'Purchase';

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            itemNote,
                            style: pw.TextStyle(color: textColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            itemDate,
                            style: pw.TextStyle(color: secondaryTextColor, fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            itemAmount,
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(color: textColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

            pw.SizedBox(height: 12),

            // Total row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total Settled',
                  style: pw.TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  totalFormatted,
                  style: pw.TextStyle(
                    color: successColor,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  @override
  Future<File> generateAndSavePdf(SettlementReceipt receipt) async {
    final pdfBytes = await generatePdfBytes(receipt);

    Directory tempDir;
    if (getTemporaryDirectoryOverride != null) {
      tempDir = await getTemporaryDirectoryOverride!();
    } else {
      tempDir = await getTemporaryDirectory();
    }

    final sanitizedMerchantName = receipt.merchantName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dateSlug = DateFormat('yyyyMMdd_HHmm').format(receipt.settlementDate);
    final fileName = 'KhataFlow_Settlement_${sanitizedMerchantName}_$dateSlug.pdf';

    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }
}

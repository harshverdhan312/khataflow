import 'dart:io';
import 'dart:typed_data';
import '../../features/receipt/domain/settlement_receipt.dart';

abstract class SettlementPdfService {
  /// Generates a PDF byte array for a successfully SETTLED SettlementReceipt.
  /// Throws a [StateError] if [receipt.status] is not 'SETTLED'.
  Future<Uint8List> generatePdfBytes(SettlementReceipt receipt);

  /// Generates and writes a PDF file to the temporary directory.
  /// Throws a [StateError] if [receipt.status] is not 'SETTLED'.
  Future<File> generateAndSavePdf(SettlementReceipt receipt);
}

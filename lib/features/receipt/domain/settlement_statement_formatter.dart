import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import 'settlement_receipt.dart';

class SettlementStatementFormatter {
  const SettlementStatementFormatter._();

  /// Converts a SettlementReceipt into a clean, shareable plain-text statement.
  /// Pure domain logic using integer paise formatting without float/double arithmetic.
  static String format(SettlementReceipt receipt) {
    final buffer = StringBuffer();

    buffer.writeln('KhataFlow Settlement Statement');
    buffer.writeln();
    buffer.writeln('Paid to: ${receipt.merchantName}');
    if (receipt.merchantUpiVpa.isNotEmpty) {
      buffer.writeln('UPI ID: ${receipt.merchantUpiVpa}');
    }
    buffer.writeln();
    buffer.writeln('Amount Settled: ${CurrencyFormatter.formatPaise(receipt.amountPaise)}');
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(receipt.settlementDate);
    buffer.writeln('Date: $formattedDate');
    buffer.writeln();
    buffer.writeln('Items Settled');
    buffer.writeln('--------------------');

    if (receipt.items.isEmpty) {
      buffer.writeln('Direct settlement with merchant');
    } else {
      for (final item in receipt.items) {
        final note = item.note.isNotEmpty ? item.note : 'Purchase';
        final amount = CurrencyFormatter.formatPaise(item.amountPaise);
        buffer.writeln('$note: $amount');
      }
    }

    buffer.writeln('--------------------');
    buffer.writeln('Total Settled: ${CurrencyFormatter.formatPaise(receipt.totalSettledPaise)}');

    final hasUtr = receipt.utr != null && receipt.utr!.isNotEmpty;
    final hasTxnId = receipt.transactionId != null && receipt.transactionId!.isNotEmpty;

    if (hasUtr || hasTxnId) {
      buffer.writeln();
      if (hasUtr) {
        buffer.writeln('Payment Reference: ${receipt.utr}');
      }
      if (hasTxnId) {
        buffer.writeln('Transaction ID: ${receipt.transactionId}');
      }
    }

    buffer.writeln();
    buffer.writeln('This is a local ledger record. KhataFlow does not hold or process funds.');

    return buffer.toString().trim();
  }
}

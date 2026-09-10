import 'package:meta/meta.dart';

@immutable
class ReceiptPurchaseItem {
  final String purchaseId;
  final String note;
  final int amountPaise;
  final DateTime purchaseDate;
  final String? category;

  const ReceiptPurchaseItem({
    required this.purchaseId,
    required this.note,
    required this.amountPaise,
    required this.purchaseDate,
    this.category,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptPurchaseItem &&
          runtimeType == other.runtimeType &&
          purchaseId == other.purchaseId &&
          note == other.note &&
          amountPaise == other.amountPaise &&
          purchaseDate == other.purchaseDate &&
          category == other.category;

  @override
  int get hashCode => Object.hash(purchaseId, note, amountPaise, purchaseDate, category);
}

@immutable
class SettlementReceipt {
  final String settlementId;
  final String merchantId;
  final String merchantName;
  final String merchantUpiVpa;
  final int amountPaise;
  final String status;
  final DateTime settlementDate;
  final String? utr;
  final String? transactionId;
  final List<ReceiptPurchaseItem> items;
  final int totalSettledPaise;

  const SettlementReceipt({
    required this.settlementId,
    required this.merchantId,
    required this.merchantName,
    required this.merchantUpiVpa,
    required this.amountPaise,
    required this.status,
    required this.settlementDate,
    this.utr,
    this.transactionId,
    required this.items,
    required this.totalSettledPaise,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettlementReceipt &&
          runtimeType == other.runtimeType &&
          settlementId == other.settlementId &&
          merchantId == other.merchantId &&
          merchantName == other.merchantName &&
          merchantUpiVpa == other.merchantUpiVpa &&
          amountPaise == other.amountPaise &&
          status == other.status &&
          settlementDate == other.settlementDate &&
          utr == other.utr &&
          transactionId == other.transactionId &&
          totalSettledPaise == other.totalSettledPaise;

  @override
  int get hashCode => Object.hash(
        settlementId,
        merchantId,
        merchantName,
        merchantUpiVpa,
        amountPaise,
        status,
        settlementDate,
        utr,
        transactionId,
        totalSettledPaise,
      );
}

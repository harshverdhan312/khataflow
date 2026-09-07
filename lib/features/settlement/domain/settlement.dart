import '../../../shared/models/sync_enums.dart';
import 'settlement_item.dart';
import 'settlement_status.dart';

class Settlement {
  final String id;
  final String merchantId;
  final int amountPaise;
  final SettlementStatus status;
  final String? transactionId;
  final String? utr;
  final DateTime initiatedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final List<SettlementItem> items;

  const Settlement({
    required this.id,
    required this.merchantId,
    required this.amountPaise,
    required this.status,
    this.transactionId,
    this.utr,
    required this.initiatedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
    this.items = const [],
  });

  Settlement copyWith({
    String? id,
    String? merchantId,
    int? amountPaise,
    SettlementStatus? status,
    String? transactionId,
    String? utr,
    DateTime? initiatedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    List<SettlementItem>? items,
  }) {
    return Settlement(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      amountPaise: amountPaise ?? this.amountPaise,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      utr: utr ?? this.utr,
      initiatedAt: initiatedAt ?? this.initiatedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      items: items ?? this.items,
    );
  }
}

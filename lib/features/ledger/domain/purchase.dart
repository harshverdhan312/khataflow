import '../../../shared/models/sync_enums.dart';

class Purchase {
  final String id;
  final String merchantId;
  final int amountPaise;
  final String note;
  final String? category;
  final DateTime purchaseDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final bool isSettled;

  const Purchase({
    required this.id,
    required this.merchantId,
    required this.amountPaise,
    required this.note,
    this.category,
    required this.purchaseDate,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
    this.isSettled = false,
  });

  Purchase copyWith({
    String? id,
    String? merchantId,
    int? amountPaise,
    String? note,
    String? category,
    DateTime? purchaseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    bool? isSettled,
  }) {
    return Purchase(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      amountPaise: amountPaise ?? this.amountPaise,
      note: note ?? this.note,
      category: category ?? this.category,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}

class CreatePurchaseInput {
  final String merchantId;
  final int amountPaise;
  final String note;
  final String? category;
  final DateTime purchaseDate;

  const CreatePurchaseInput({
    required this.merchantId,
    required this.amountPaise,
    required this.note,
    this.category,
    required this.purchaseDate,
  });
}

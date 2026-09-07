enum SyncEntityType {
  merchant,
  purchase,
  settlement,
  settlementItem;

  String toDbValue() {
    switch (this) {
      case SyncEntityType.merchant:
        return 'MERCHANT';
      case SyncEntityType.purchase:
        return 'PURCHASE';
      case SyncEntityType.settlement:
        return 'SETTLEMENT';
      case SyncEntityType.settlementItem:
        return 'SETTLEMENT_ITEM';
    }
  }

  static SyncEntityType fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'MERCHANT':
        return SyncEntityType.merchant;
      case 'PURCHASE':
        return SyncEntityType.purchase;
      case 'SETTLEMENT':
        return SyncEntityType.settlement;
      case 'SETTLEMENT_ITEM':
        return SyncEntityType.settlementItem;
      default:
        throw ArgumentError('Unknown SyncEntityType: $value');
    }
  }
}

enum SyncOperation {
  upsert,
  delete;

  String toDbValue() {
    switch (this) {
      case SyncOperation.upsert:
        return 'UPSERT';
      case SyncOperation.delete:
        return 'DELETE';
    }
  }

  static SyncOperation fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'UPSERT':
        return SyncOperation.upsert;
      case 'DELETE':
        return SyncOperation.delete;
      default:
        throw ArgumentError('Unknown SyncOperation: $value');
    }
  }
}

enum SyncStatus {
  pending,
  synced,
  failed;

  String toDbValue() {
    switch (this) {
      case SyncStatus.pending:
        return 'PENDING';
      case SyncStatus.synced:
        return 'SYNCED';
      case SyncStatus.failed:
        return 'FAILED';
    }
  }

  static SyncStatus fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return SyncStatus.pending;
      case 'SYNCED':
        return SyncStatus.synced;
      case 'FAILED':
        return SyncStatus.failed;
      default:
        return SyncStatus.pending;
    }
  }
}

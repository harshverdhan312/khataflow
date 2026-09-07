import 'sync_enums.dart';

class SyncQueueItem {
  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperation operation;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final DateTime createdAt;

  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.attemptCount = 0,
    this.lastAttemptAt,
    this.lastError,
    required this.createdAt,
  });

  SyncQueueItem copyWith({
    String? id,
    SyncEntityType? entityType,
    String? entityId,
    SyncOperation? operation,
    int? attemptCount,
    DateTime? lastAttemptAt,
    String? lastError,
    DateTime? createdAt,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

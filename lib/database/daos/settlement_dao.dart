import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/settlement_items_table.dart';
import '../tables/settlements_table.dart';
import '../tables/sync_queue_table.dart';

part 'settlement_dao.g.dart';

@DriftAccessor(tables: [Settlements, SettlementItems, SyncQueue])
class SettlementDao extends DatabaseAccessor<AppDatabase> with _$SettlementDaoMixin {
  SettlementDao(super.db);

  Stream<List<SettlementEntity>> watchSettlementsForMerchant(String merchantId) {
    return (select(settlements)
          ..where((tbl) => tbl.merchantId.equals(merchantId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.initiatedAt)]))
        .watch();
  }

  Stream<List<SettlementEntity>> watchAllSettlements() {
    return (select(settlements)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.initiatedAt)]))
        .watch();
  }

  Future<List<SettlementEntity>> getAllSettlements() {
    return (select(settlements)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.initiatedAt)]))
        .get();
  }

  Future<SettlementEntity?> getSettlementById(String id) {
    return (select(settlements)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<SettlementItemEntity>> getSettlementItems(String settlementId) {
    return (select(settlementItems)
          ..where((tbl) => tbl.settlementId.equals(settlementId)))
        .get();
  }

  /// Inserts a settlement, its linked items, and a sync queue record inside a single SQLite transaction.
  Future<void> insertSettlementWithItemsAndSync({
    required SettlementsCompanion settlement,
    required List<SettlementItemsCompanion> items,
    required SyncQueueCompanion syncEntry,
  }) {
    return transaction(() async {
      await into(settlements).insert(settlement);
      for (final item in items) {
        await into(settlementItems).insert(item);
      }
      await into(syncQueue).insert(syncEntry);
    });
  }

  /// Inserts a settlement and its linked items inside a single SQLite transaction.
  Future<void> insertSettlementWithItems({
    required SettlementsCompanion settlement,
    required List<SettlementItemsCompanion> items,
  }) {
    return transaction(() async {
      await into(settlements).insert(settlement);
      for (final item in items) {
        await into(settlementItems).insert(item);
      }
    });
  }

  /// Updates settlement status, transaction details, and timestamps.
  Future<int> updateSettlementStatus({
    required String settlementId,
    required String status,
    String? transactionId,
    String? utr,
    int? completedAt,
    required int updatedAt,
  }) {
    return (update(settlements)..where((tbl) => tbl.id.equals(settlementId))).write(
      SettlementsCompanion(
        status: Value(status),
        transactionId: transactionId != null ? Value(transactionId) : const Value.absent(),
        utr: utr != null ? Value(utr) : const Value.absent(),
        completedAt: completedAt != null ? Value(completedAt) : const Value.absent(),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Returns unresolved settlements (INITIATED, UPI_LAUNCHED, UNKNOWN).
  Future<List<SettlementEntity>> getUnresolvedSettlements({String? merchantId}) {
    final query = select(settlements)
      ..where((tbl) {
        final statusCondition = tbl.status.isIn(['INITIATED', 'UPI_LAUNCHED', 'UNKNOWN']);
        if (merchantId != null) {
          return statusCondition & tbl.merchantId.equals(merchantId);
        }
        return statusCondition;
      })
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.initiatedAt)]);
    return query.get();
  }

  /// Returns all purchase IDs currently part of an unresolved settlement for this merchant.
  Future<List<String>> getUnresolvedPurchaseIds(String merchantId) async {
    final sql = '''
      SELECT si.purchase_id
      FROM settlement_items si
      INNER JOIN settlements s ON s.id = si.settlement_id
      WHERE s.merchant_id = ?
        AND s.status IN ('INITIATED', 'UPI_LAUNCHED', 'UNKNOWN')
    ''';

    final result = await customSelect(
      sql,
      variables: [Variable.withString(merchantId)],
      readsFrom: {settlements, settlementItems},
    ).get();

    return result.map((row) => row.read<String>('purchase_id')).toList();
  }

  Future<int> updateSyncStatus(String id, String syncStatus, int updatedAt) {
    return (update(settlements)..where((tbl) => tbl.id.equals(id))).write(
      SettlementsCompanion(
        syncStatus: Value(syncStatus),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}


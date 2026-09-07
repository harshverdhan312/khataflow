import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/settlement_items_table.dart';
import '../tables/settlements_table.dart';

part 'settlement_dao.g.dart';

@DriftAccessor(tables: [Settlements, SettlementItems])
class SettlementDao extends DatabaseAccessor<AppDatabase> with _$SettlementDaoMixin {
  SettlementDao(super.db);

  Stream<List<SettlementEntity>> watchSettlementsForMerchant(String merchantId) {
    return (select(settlements)
          ..where((tbl) => tbl.merchantId.equals(merchantId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.initiatedAt)]))
        .watch();
  }

  Future<SettlementEntity?> getSettlementById(String id) {
    return (select(settlements)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<SettlementItemEntity>> getSettlementItems(String settlementId) {
    return (select(settlementItems)
          ..where((tbl) => tbl.settlementId.equals(settlementId)))
        .get();
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

  Future<int> updateSyncStatus(String id, String syncStatus, int updatedAt) {
    return (update(settlements)..where((tbl) => tbl.id.equals(id))).write(
      SettlementsCompanion(
        syncStatus: Value(syncStatus),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}

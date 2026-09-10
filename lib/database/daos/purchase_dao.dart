import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/merchants_table.dart';
import '../tables/purchases_table.dart';
import '../tables/settlement_items_table.dart';
import '../tables/settlements_table.dart';

part 'purchase_dao.g.dart';

class PurchaseWithSettledStatus {
  final PurchaseEntity purchase;
  final bool isSettled;

  const PurchaseWithSettledStatus({
    required this.purchase,
    required this.isSettled,
  });
}

@DriftAccessor(tables: [Purchases, Settlements, SettlementItems, Merchants])
class PurchaseDao extends DatabaseAccessor<AppDatabase> with _$PurchaseDaoMixin {
  PurchaseDao(super.db);

  Stream<List<PurchaseEntity>> watchPurchases(String merchantId) {
    return (select(purchases)
          ..where((tbl) => tbl.merchantId.equals(merchantId))
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.purchaseDate),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch();
  }

  /// Watches purchases with their derived settlement status.
  Stream<List<PurchaseWithSettledStatus>> watchPurchasesWithSettledStatus(String merchantId) {
    final sql = '''
      SELECT 
        p.id, 
        p.merchant_id, 
        p.amount_paise, 
        p.note, 
        p.category, 
        p.purchase_date, 
        p.created_at, 
        p.updated_at, 
        p.sync_status,
        EXISTS(
          SELECT 1 
          FROM settlement_items si
          INNER JOIN settlements s ON s.id = si.settlement_id
          WHERE si.purchase_id = p.id 
            AND s.status IN ('SETTLED', 'SUCCESS')
        ) AS is_settled
      FROM purchases p
      WHERE p.merchant_id = ?
      ORDER BY p.purchase_date DESC, p.created_at DESC
    ''';

    return customSelect(
      sql,
      variables: [Variable.withString(merchantId)],
      readsFrom: {purchases, settlements, settlementItems},
    ).watch().map((rows) {
      return rows.map((row) {
        return PurchaseWithSettledStatus(
          purchase: PurchaseEntity(
            id: row.read<String>('id'),
            merchantId: row.read<String>('merchant_id'),
            amountPaise: row.read<int>('amount_paise'),
            note: row.read<String>('note'),
            category: row.readNullable<String>('category'),
            purchaseDate: row.read<int>('purchase_date'),
            createdAt: row.read<int>('created_at'),
            updatedAt: row.read<int>('updated_at'),
            syncStatus: row.read<String>('sync_status'),
          ),
          isSettled: (row.read<int>('is_settled')) == 1,
        );
      }).toList();
    });
  }

  Future<List<PurchaseEntity>> getPurchases(String merchantId) {
    return (select(purchases)
          ..where((tbl) => tbl.merchantId.equals(merchantId))
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.purchaseDate),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .get();
  }

  /// Gets purchases with their derived settlement status.
  Future<List<PurchaseWithSettledStatus>> getPurchasesWithSettledStatus(String merchantId) async {
    final sql = '''
      SELECT 
        p.id, 
        p.merchant_id, 
        p.amount_paise, 
        p.note, 
        p.category, 
        p.purchase_date, 
        p.created_at, 
        p.updated_at, 
        p.sync_status,
        EXISTS(
          SELECT 1 
          FROM settlement_items si
          INNER JOIN settlements s ON s.id = si.settlement_id
          WHERE si.purchase_id = p.id 
            AND s.status IN ('SETTLED', 'SUCCESS')
        ) AS is_settled
      FROM purchases p
      WHERE p.merchant_id = ?
      ORDER BY p.purchase_date DESC, p.created_at DESC
    ''';

    final rows = await customSelect(
      sql,
      variables: [Variable.withString(merchantId)],
      readsFrom: {purchases, settlements, settlementItems},
    ).get();

    return rows.map((row) {
      return PurchaseWithSettledStatus(
        purchase: PurchaseEntity(
          id: row.read<String>('id'),
          merchantId: row.read<String>('merchant_id'),
          amountPaise: row.read<int>('amount_paise'),
          note: row.read<String>('note'),
          category: row.readNullable<String>('category'),
          purchaseDate: row.read<int>('purchase_date'),
          createdAt: row.read<int>('created_at'),
          updatedAt: row.read<int>('updated_at'),
          syncStatus: row.read<String>('sync_status'),
        ),
        isSettled: (row.read<int>('is_settled')) == 1,
      );
    }).toList();
  }

  Future<PurchaseEntity?> getPurchaseById(String id) {
    return (select(purchases)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertPurchase(PurchasesCompanion entry) {
    return into(purchases).insert(entry);
  }

  Future<int> updateSyncStatus(String id, String syncStatus, int updatedAt) {
    return (update(purchases)..where((tbl) => tbl.id.equals(id))).write(
      PurchasesCompanion(
        syncStatus: Value(syncStatus),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Returns purchases for a merchant that have NOT been settled successfully.
  Future<List<PurchaseEntity>> getUnsettledPurchases(String merchantId) async {
    final query = select(purchases)
      ..where((p) {
        final settledSubquery = selectOnly(settlementItems)
          ..addColumns([settlementItems.purchaseId])
          ..join([
            innerJoin(
              settlements,
              settlements.id.equalsExp(settlementItems.settlementId),
            ),
          ])
          ..where(settlements.status.isIn(['SUCCESS', 'SETTLED']));

        return p.merchantId.equals(merchantId) &
            p.id.isNotInQuery(settledSubquery);
      })
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.purchaseDate),
        (tbl) => OrderingTerm.desc(tbl.createdAt),
      ]);

    return query.get();
  }

  /// Streams the total outstanding paise for a specific merchant.
  Stream<int> watchOutstandingAmount(String merchantId) {
    final sql = '''
      SELECT COALESCE(SUM(amount_paise), 0) AS total
      FROM purchases
      WHERE merchant_id = ?
        AND id NOT IN (
          SELECT si.purchase_id
          FROM settlement_items si
          INNER JOIN settlements s ON s.id = si.settlement_id
          WHERE s.status IN ('SUCCESS', 'SETTLED')
        )
    ''';

    return customSelect(
      sql,
      variables: [Variable.withString(merchantId)],
      readsFrom: {purchases, settlements, settlementItems},
    ).watchSingle().map((row) => row.read<int>('total'));
  }

  /// Gets the total outstanding paise for a specific merchant.
  Future<int> getOutstandingAmount(String merchantId) async {
    final sql = '''
      SELECT COALESCE(SUM(amount_paise), 0) AS total
      FROM purchases
      WHERE merchant_id = ?
        AND id NOT IN (
          SELECT si.purchase_id
          FROM settlement_items si
          INNER JOIN settlements s ON s.id = si.settlement_id
          WHERE s.status IN ('SUCCESS', 'SETTLED')
        )
    ''';

    final result = await customSelect(
      sql,
      variables: [Variable.withString(merchantId)],
      readsFrom: {purchases, settlements, settlementItems},
    ).getSingle();

    return result.read<int>('total');
  }

  /// Streams the total outstanding paise across all active merchants.
  Stream<int> watchTotalOutstanding() {
    final sql = '''
      SELECT COALESCE(SUM(p.amount_paise), 0) AS total
      FROM purchases p
      INNER JOIN merchants m ON m.id = p.merchant_id
      WHERE m.is_active = 1
        AND p.id NOT IN (
          SELECT si.purchase_id
          FROM settlement_items si
          INNER JOIN settlements s ON s.id = si.settlement_id
          WHERE s.status IN ('SUCCESS', 'SETTLED')
        )
    ''';

    return customSelect(
      sql,
      readsFrom: {purchases, settlements, settlementItems, merchants},
    ).watchSingle().map((row) => row.read<int>('total'));
  }

  /// Gets the total outstanding paise across all active merchants.
  Future<int> getTotalOutstanding() async {
    final sql = '''
      SELECT COALESCE(SUM(p.amount_paise), 0) AS total
      FROM purchases p
      INNER JOIN merchants m ON m.id = p.merchant_id
      WHERE m.is_active = 1
        AND p.id NOT IN (
          SELECT si.purchase_id
          FROM settlement_items si
          INNER JOIN settlements s ON s.id = si.settlement_id
          WHERE s.status IN ('SUCCESS', 'SETTLED')
        )
    ''';

    final result = await customSelect(
      sql,
      readsFrom: {purchases, settlements, settlementItems, merchants},
    ).getSingle();

    return result.read<int>('total');
  }
}

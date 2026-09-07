import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/merchants_table.dart';

part 'merchant_dao.g.dart';

@DriftAccessor(tables: [Merchants])
class MerchantDao extends DatabaseAccessor<AppDatabase> with _$MerchantDaoMixin {
  MerchantDao(super.db);

  Stream<List<MerchantEntity>> watchActiveMerchants() {
    return (select(merchants)
          ..where((tbl) => tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch();
  }

  Future<List<MerchantEntity>> getActiveMerchants() {
    return (select(merchants)
          ..where((tbl) => tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .get();
  }

  Future<List<MerchantEntity>> getAllMerchants() {
    return (select(merchants)..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])).get();
  }

  Future<MerchantEntity?> getMerchantById(String id) {
    return (select(merchants)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertMerchant(MerchantsCompanion entry) {
    return into(merchants).insert(entry);
  }

  Future<bool> updateMerchant(MerchantsCompanion entry) {
    return update(merchants).replace(entry);
  }

  Future<int> deactivateMerchant(String id, int updatedAt) {
    return (update(merchants)..where((tbl) => tbl.id.equals(id))).write(
      MerchantsCompanion(
        isActive: const Value(false),
        updatedAt: Value(updatedAt),
      ),
    );
  }
}

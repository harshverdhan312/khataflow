import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../core/constants/app_constants.dart';
import 'daos/merchant_dao.dart';
import 'daos/purchase_dao.dart';
import 'daos/settlement_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'tables/merchants_table.dart';
import 'tables/purchases_table.dart';
import 'tables/settlement_items_table.dart';
import 'tables/settlements_table.dart';
import 'tables/sync_queue_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Merchants,
    Purchases,
    Settlements,
    SettlementItems,
    SyncQueue,
  ],
  daos: [
    MerchantDao,
    PurchaseDao,
    SettlementDao,
    SyncQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => AppConstants.databaseSchemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Schema migrations for future versions will be handled here
      },
      beforeOpen: (details) async {
        // Enable foreign key constraints in SQLite
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'khata_flow',
      native: const DriftNativeOptions(
        shareAcrossIsolates: true,
      ),
    );
  }
}

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../core/constants/app_constants.dart';
import 'daos/expense_dao.dart';
import 'daos/merchant_dao.dart';
import 'daos/purchase_dao.dart';
import 'daos/settlement_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'tables/expenses_table.dart';
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
    Expenses,
  ],
  daos: [
    MerchantDao,
    PurchaseDao,
    SettlementDao,
    SyncQueueDao,
    ExpenseDao,
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
        await customStatement('CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses (expense_date DESC);');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_expenses_category_date ON expenses (category, expense_date DESC);');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(expenses);
          await customStatement('CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses (expense_date DESC);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_expenses_category_date ON expenses (category, expense_date DESC);');
        }
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

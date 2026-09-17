import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/database/app_database.dart';

void main() {
  group('Schema Migration Tests (v1 -> v2)', () {
    test('migrates database from schema v1 to v2 non-destructively', () async {
      const now = 1700000000000;

      // 1. Create in-memory database with pre-populated v1 schema and data via setup hook
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('''
              CREATE TABLE merchants (
                id TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                phone TEXT,
                upi_vpa TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
                sync_status TEXT NOT NULL DEFAULT 'PENDING'
              );

              CREATE TABLE purchases (
                id TEXT NOT NULL PRIMARY KEY,
                merchant_id TEXT NOT NULL REFERENCES merchants(id),
                amount_paise INTEGER NOT NULL,
                note TEXT,
                item_summary TEXT,
                purchase_date INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                sync_status TEXT NOT NULL DEFAULT 'PENDING'
              );

              CREATE TABLE settlements (
                id TEXT NOT NULL PRIMARY KEY,
                merchant_id TEXT NOT NULL REFERENCES merchants(id),
                amount_paise INTEGER NOT NULL,
                status TEXT NOT NULL DEFAULT 'INITIATED',
                utr TEXT,
                transaction_id TEXT,
                initiated_at INTEGER NOT NULL,
                completed_at INTEGER,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                sync_status TEXT NOT NULL DEFAULT 'PENDING'
              );

              CREATE TABLE settlement_items (
                settlement_id TEXT NOT NULL REFERENCES settlements(id),
                purchase_id TEXT NOT NULL REFERENCES purchases(id),
                amount_paise INTEGER NOT NULL,
                PRIMARY KEY (settlement_id, purchase_id)
              );

              CREATE TABLE sync_queue (
                id TEXT NOT NULL PRIMARY KEY,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                operation TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                attempt_count INTEGER NOT NULL DEFAULT 0,
                last_attempted_at INTEGER,
                last_error TEXT
              );

              CREATE INDEX idx_purchases_merchant_date ON purchases(merchant_id, purchase_date);
              CREATE INDEX idx_settlements_merchant_date ON settlements(merchant_id, initiated_at);
              CREATE INDEX idx_sync_queue_created ON sync_queue(created_at);

              PRAGMA user_version = 1;

              INSERT INTO merchants (id, name, category, phone, upi_vpa, created_at, updated_at, is_active, sync_status)
              VALUES ('m1', 'Sharma Kirana', 'GROCERY', '9876543210', 'sharma@upi', $now, $now, 1, 'SYNCED');

              INSERT INTO purchases (id, merchant_id, amount_paise, note, purchase_date, created_at, updated_at, sync_status)
              VALUES ('p1', 'm1', 25000, 'Rice & Dal', $now, $now, $now, 'SYNCED');

              INSERT INTO settlements (id, merchant_id, amount_paise, status, initiated_at, created_at, updated_at, sync_status)
              VALUES ('s1', 'm1', 25000, 'INITIATED', $now, $now, $now, 'PENDING');

              INSERT INTO settlement_items (settlement_id, purchase_id, amount_paise)
              VALUES ('s1', 'p1', 25000);

              INSERT INTO sync_queue (id, entity_type, entity_id, operation, created_at)
              VALUES ('q1', 'PURCHASE', 'p1', 'UPSERT', $now);
            ''');
          },
        ),
      );

      // Check schema version upgraded to 2
      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      final schemaVersion = versionResult.read<int>('user_version');
      expect(schemaVersion, 2);

      // 3. Verify ALL pre-existing v1 data survived completely intact
      final merchants = await db.merchantDao.getAllMerchants();
      expect(merchants.length, 1);
      expect(merchants.first.id, 'm1');
      expect(merchants.first.name, 'Sharma Kirana');
      expect(merchants.first.category, 'GROCERY');

      final purchase = await db.purchaseDao.getPurchaseById('p1');
      expect(purchase, isNotNull);
      expect(purchase!.amountPaise, 25000);
      expect(purchase.note, 'Rice & Dal');

      final settlement = await db.settlementDao.getSettlementById('s1');
      expect(settlement, isNotNull);
      expect(settlement!.amountPaise, 25000);
      expect(settlement.status, 'INITIATED');

      final syncQueue = await db.syncQueueDao.getPendingItems();
      expect(syncQueue.length, 1);
      expect(syncQueue.first.id, 'q1');
      expect(syncQueue.first.entityType, 'PURCHASE');

      // 4. Verify new Expenses table works correctly in the upgraded database
      await db.expenseDao.insertExpense(
        const ExpensesCompanion(
          id: Value('exp_migrated_1'),
          amountPaise: Value(14500),
          category: Value('FOOD'),
          note: Value('Post-migration test expense'),
          expenseDate: Value(now + 10000),
          createdAt: Value(now + 10000),
          updatedAt: Value(now + 10000),
          syncStatus: Value('PENDING'),
        ),
      );

      final expenses = await db.expenseDao.getExpenses();
      expect(expenses.length, 1);
      expect(expenses.first.id, 'exp_migrated_1');
      expect(expenses.first.amountPaise, 14500);
      expect(expenses.first.category, 'FOOD');
      expect(expenses.first.note, 'Post-migration test expense');

      await db.close();
    });
  });
}

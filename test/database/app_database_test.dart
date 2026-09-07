import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('MerchantDao Tests', () {
    test('inserts and retrieves active merchants', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.merchantDao.insertMerchant(
        MerchantsCompanion(
          id: const Value('m1'),
          name: const Value('Sharma Kirana'),
          category: const Value('GROCERY'),
          phone: const Value('9876543210'),
          upiVpa: const Value('sharma@upi'),
          createdAt: Value(now),
          updatedAt: Value(now),
          isActive: const Value(true),
        ),
      );

      final activeMerchants = await db.merchantDao.getActiveMerchants();
      expect(activeMerchants.length, 1);
      expect(activeMerchants.first.name, 'Sharma Kirana');
      expect(activeMerchants.first.upiVpa, 'sharma@upi');

      // Test deactivation
      await db.merchantDao.deactivateMerchant('m1', now + 1000);
      final afterDeactivation = await db.merchantDao.getActiveMerchants();
      expect(afterDeactivation.isEmpty, true);

      final allMerchants = await db.merchantDao.getAllMerchants();
      expect(allMerchants.length, 1);
      expect(allMerchants.first.isActive, false);
    });
  });

  group('PurchaseDao & Balance Calculation Tests', () {
    final now = DateTime.now().millisecondsSinceEpoch;

    setUp(() async {
      // Create merchant
      await db.merchantDao.insertMerchant(
        MerchantsCompanion(
          id: const Value('m1'),
          name: const Value('Sharma Kirana'),
          category: const Value('GROCERY'),
          upiVpa: const Value('sharma@upi'),
          createdAt: Value(now),
          updatedAt: Value(now),
          isActive: const Value(true),
        ),
      );
    });

    test('calculates derived outstanding balance dynamically', () async {
      // Add purchases: ₹120 (12000 paise), ₹450 (45000 paise), ₹200 (20000 paise) -> Total: ₹770 (77000 paise)
      await db.purchaseDao.insertPurchase(
        PurchasesCompanion(
          id: const Value('p1'),
          merchantId: const Value('m1'),
          amountPaise: const Value(12000),
          note: const Value('Bread & Eggs'),
          purchaseDate: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.purchaseDao.insertPurchase(
        PurchasesCompanion(
          id: const Value('p2'),
          merchantId: const Value('m1'),
          amountPaise: const Value(45000),
          note: const Value('Vegetables'),
          purchaseDate: Value(now + 1000),
          createdAt: Value(now + 1000),
          updatedAt: Value(now + 1000),
        ),
      );

      await db.purchaseDao.insertPurchase(
        PurchasesCompanion(
          id: const Value('p3'),
          merchantId: const Value('m1'),
          amountPaise: const Value(20000),
          note: const Value('Milk'),
          purchaseDate: Value(now + 2000),
          createdAt: Value(now + 2000),
          updatedAt: Value(now + 2000),
        ),
      );

      final outstanding = await db.purchaseDao.getOutstandingAmount('m1');
      expect(outstanding, 77000);

      final totalOutstanding = await db.purchaseDao.getTotalOutstanding();
      expect(totalOutstanding, 77000);

      final unsettled = await db.purchaseDao.getUnsettledPurchases('m1');
      expect(unsettled.length, 3);
    });

    test('settling purchases zeroes the outstanding balance', () async {
      // Add ₹120 and ₹450 purchases
      await db.purchaseDao.insertPurchase(
        PurchasesCompanion(
          id: const Value('p1'),
          merchantId: const Value('m1'),
          amountPaise: const Value(12000),
          note: const Value('Bread & Eggs'),
          purchaseDate: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.purchaseDao.insertPurchase(
        PurchasesCompanion(
          id: const Value('p2'),
          merchantId: const Value('m1'),
          amountPaise: const Value(45000),
          note: const Value('Vegetables'),
          purchaseDate: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      expect(await db.purchaseDao.getOutstandingAmount('m1'), 57000);

      // Initiate settlement
      await db.settlementDao.insertSettlementWithItems(
        settlement: SettlementsCompanion(
          id: const Value('s1'),
          merchantId: const Value('m1'),
          amountPaise: const Value(57000),
          status: const Value('INITIATED'),
          initiatedAt: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
        items: [
          const SettlementItemsCompanion(
            settlementId: Value('s1'),
            purchaseId: Value('p1'),
            amountPaise: Value(12000),
          ),
          const SettlementItemsCompanion(
            settlementId: Value('s1'),
            purchaseId: Value('p2'),
            amountPaise: Value(45000),
          ),
        ],
      );

      // Status is INITIATED: Outstanding balance should still be ₹570 (not cleared prematurely)
      expect(await db.purchaseDao.getOutstandingAmount('m1'), 57000);

      // Now complete settlement with SUCCESS
      await db.settlementDao.updateSettlementStatus(
        settlementId: 's1',
        status: 'SETTLED',
        utr: '123456789012',
        transactionId: 'TXN12345',
        completedAt: now + 5000,
        updatedAt: now + 5000,
      );

      // Outstanding balance is now zero!
      expect(await db.purchaseDao.getOutstandingAmount('m1'), 0);
      expect(await db.purchaseDao.getTotalOutstanding(), 0);

      final unsettled = await db.purchaseDao.getUnsettledPurchases('m1');
      expect(unsettled.isEmpty, true);
    });
  });

  group('SyncQueueDao Tests', () {
    test('enqueues, retrieves FIFO, increments retry, and deletes items', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.syncQueueDao.enqueue(
        SyncQueueCompanion(
          id: const Value('q1'),
          entityType: const Value('MERCHANT'),
          entityId: const Value('m1'),
          operation: const Value('UPSERT'),
          createdAt: Value(now),
        ),
      );

      await db.syncQueueDao.enqueue(
        SyncQueueCompanion(
          id: const Value('q2'),
          entityType: const Value('PURCHASE'),
          entityId: const Value('p1'),
          operation: const Value('UPSERT'),
          createdAt: Value(now + 100),
        ),
      );

      final count = await db.syncQueueDao.getPendingCount();
      expect(count, 2);

      final items = await db.syncQueueDao.getPendingItems();
      expect(items.length, 2);
      expect(items.first.id, 'q1');

      // Test increment attempt with error
      await db.syncQueueDao.incrementAttempt(
        'q1',
        error: 'Network timeout',
        attemptedAt: now + 200,
      );

      final updatedItems = await db.syncQueueDao.getPendingItems();
      expect(updatedItems.first.attemptCount, 1);
      expect(updatedItems.first.lastError, 'Network timeout');

      // Delete item
      await db.syncQueueDao.deleteItem('q1');
      expect(await db.syncQueueDao.getPendingCount(), 1);
    });
  });
}

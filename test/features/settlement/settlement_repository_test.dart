import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/features/settlement/data/settlement_repository_impl.dart';
import 'package:khata_flow/features/settlement/domain/settlement_status.dart';

void main() {
  late AppDatabase db;
  late SettlementRepositoryImpl settlementRepo;

  const merchantId = 'm_test_1';
  const merchantVpa = 'kirana@oksbi';
  final now = DateTime.now().millisecondsSinceEpoch;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settlementRepo = SettlementRepositoryImpl(db);

    // Seed merchant
    await db.merchantDao.insertMerchant(
      MerchantsCompanion.insert(
        id: merchantId,
        name: 'Gupta General Store',
        upiVpa: merchantVpa,
        category: 'Grocery',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('SettlementRepositoryImpl', () {
    test('prevents settlement initiation with empty purchaseIds', () async {
      expect(
        () => settlementRepo.initiateSettlement(
          merchantId: merchantId,
          purchaseIds: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('prevents settlement initiation if requested purchase is invalid or missing', () async {
      expect(
        () => settlementRepo.initiateSettlement(
          merchantId: merchantId,
          purchaseIds: ['non_existent_id'],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('atomically creates settlement, items, and sync queue entry in SQLite', () async {
      // 1. Seed two purchases
      const p1Id = 'p_1';
      const p2Id = 'p_2';
      await db.purchaseDao.insertPurchase(
        PurchasesCompanion.insert(
          id: p1Id,
          merchantId: merchantId,
          amountPaise: 15000, // Rs 150.00
          note: 'Rice & Dal',
          purchaseDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.purchaseDao.insertPurchase(
        PurchasesCompanion.insert(
          id: p2Id,
          merchantId: merchantId,
          amountPaise: 5000, // Rs 50.00
          note: 'Milk packet',
          purchaseDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Initiate settlement
      final settlement = await settlementRepo.initiateSettlement(
        merchantId: merchantId,
        purchaseIds: [p1Id, p2Id],
      );

      expect(settlement.merchantId, equals(merchantId));
      expect(settlement.amountPaise, equals(20000)); // Rs 200.00
      expect(settlement.status, equals(SettlementStatus.initiated));
      expect(settlement.items.length, equals(2));

      // 3. Verify SQLite records directly
      final dbSettlement = await db.settlementDao.getSettlementById(settlement.id);
      expect(dbSettlement, isNotNull);
      expect(dbSettlement!.status, equals('INITIATED'));
      expect(dbSettlement.amountPaise, equals(20000));

      final items = await db.settlementDao.getSettlementItems(settlement.id);
      expect(items.length, equals(2));
      expect(items.map((i) => i.purchaseId).toSet(), equals({p1Id, p2Id}));

      final syncQueueItems = await db.syncQueueDao.getPendingItems();
      expect(syncQueueItems.any((item) => item.entityId == settlement.id && item.entityType == 'SETTLEMENT'), isTrue);
    });

    test('protects against duplicate unresolved settlements for the same merchant', () async {
      // Seed purchase
      const p1Id = 'p_dup_1';
      await db.purchaseDao.insertPurchase(
        PurchasesCompanion.insert(
          id: p1Id,
          merchantId: merchantId,
          amountPaise: 10000,
          note: 'Groceries',
          purchaseDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Initiate first settlement
      await settlementRepo.initiateSettlement(
        merchantId: merchantId,
        purchaseIds: [p1Id],
      );

      // Attempt second settlement without resolving first
      expect(
        () => settlementRepo.initiateSettlement(
          merchantId: merchantId,
          purchaseIds: [p1Id],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('transitions INITIATED -> UPI_LAUNCHED -> SETTLED and excludes purchases from outstanding', () async {
      const p1Id = 'p_trans_1';
      await db.purchaseDao.insertPurchase(
        PurchasesCompanion.insert(
          id: p1Id,
          merchantId: merchantId,
          amountPaise: 50000, // Rs 500
          note: 'Provisions',
          purchaseDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Verify initial outstanding
      var outstanding = await db.purchaseDao.getOutstandingAmount(merchantId);
      expect(outstanding, equals(50000));

      // 1. INITIATED
      final settlement = await settlementRepo.initiateSettlement(
        merchantId: merchantId,
        purchaseIds: [p1Id],
      );
      // Still outstanding while INITIATED
      outstanding = await db.purchaseDao.getOutstandingAmount(merchantId);
      expect(outstanding, equals(50000));

      // 2. UPI_LAUNCHED
      await settlementRepo.markUpiLaunched(settlement.id);
      var fetched = await settlementRepo.getSettlementById(settlement.id);
      expect(fetched!.status, equals(SettlementStatus.upiLaunched));
      // Still outstanding while UPI_LAUNCHED
      outstanding = await db.purchaseDao.getOutstandingAmount(merchantId);
      expect(outstanding, equals(50000));

      // 3. SETTLED
      await settlementRepo.markSettlementSettled(
        settlementId: settlement.id,
        utr: '123456789012',
        transactionId: 'TXN123',
      );
      fetched = await settlementRepo.getSettlementById(settlement.id);
      expect(fetched!.status, equals(SettlementStatus.settled));
      expect(fetched.utr, equals('123456789012'));
      expect(fetched.transactionId, equals('TXN123'));
      expect(fetched.completedAt, isNotNull);

      // Once SETTLED, purchases are excluded from outstanding dues
      outstanding = await db.purchaseDao.getOutstandingAmount(merchantId);
      expect(outstanding, equals(0));

      // Historical purchase record remains intact
      final allPurchases = await db.purchaseDao.getPurchases(merchantId);
      expect(allPurchases.length, equals(1));
      expect(allPurchases.first.id, equals(p1Id));
    });

    test('FAILED settlement preserves outstanding dues and allows new settlement', () async {
      const p1Id = 'p_fail_1';
      await db.purchaseDao.insertPurchase(
        PurchasesCompanion.insert(
          id: p1Id,
          merchantId: merchantId,
          amountPaise: 30000,
          note: 'Spices',
          purchaseDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final settlement = await settlementRepo.initiateSettlement(
        merchantId: merchantId,
        purchaseIds: [p1Id],
      );
      await settlementRepo.markUpiLaunched(settlement.id);

      // User marks payment as FAILED
      await settlementRepo.markSettlementFailed(
        settlementId: settlement.id,
        reason: 'Payment cancelled in UPI app',
      );

      final fetched = await settlementRepo.getSettlementById(settlement.id);
      expect(fetched!.status, equals(SettlementStatus.failed));

      // Outstanding dues remain intact
      final outstanding = await db.purchaseDao.getOutstandingAmount(merchantId);
      expect(outstanding, equals(30000));

      // Unresolved flag is now false, allowing user to retry/initiate a new settlement
      final hasUnresolved = await settlementRepo.hasUnresolvedSettlementForMerchant(merchantId);
      expect(hasUnresolved, isFalse);

      final newSettlement = await settlementRepo.initiateSettlement(
        merchantId: merchantId,
        purchaseIds: [p1Id],
      );
      expect(newSettlement.id, isNot(equals(settlement.id)));
    });

    test('UNKNOWN settlement preserves outstanding dues and can be recovered later', () async {
      const p1Id = 'p_unk_1';
      await db.purchaseDao.insertPurchase(
        PurchasesCompanion.insert(
          id: p1Id,
          merchantId: merchantId,
          amountPaise: 45000,
          note: 'Stationery',
          purchaseDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final settlement = await settlementRepo.initiateSettlement(
        merchantId: merchantId,
        purchaseIds: [p1Id],
      );
      await settlementRepo.markUpiLaunched(settlement.id);
      await settlementRepo.markSettlementUnknown(settlementId: settlement.id);

      final fetched = await settlementRepo.getSettlementById(settlement.id);
      expect(fetched!.status, equals(SettlementStatus.unknown));

      // Dues preserved
      final outstanding = await db.purchaseDao.getOutstandingAmount(merchantId);
      expect(outstanding, equals(45000));

      // Recovered in unresolved list
      final unresolved = await settlementRepo.getUnresolvedSettlements(merchantId: merchantId);
      expect(unresolved.length, equals(1));
      expect(unresolved.first.id, equals(settlement.id));

      // Resolve it later as SETTLED
      await settlementRepo.markSettlementSettled(settlementId: settlement.id);
      final finalOutstanding = await db.purchaseDao.getOutstandingAmount(merchantId);
      expect(finalOutstanding, equals(0));
    });
  });
}

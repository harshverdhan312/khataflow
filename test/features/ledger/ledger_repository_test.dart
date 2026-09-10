import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/errors/app_exceptions.dart';
import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/features/ledger/data/ledger_repository_impl.dart';
import 'package:khata_flow/features/ledger/domain/purchase.dart';
import 'package:khata_flow/features/merchant/data/merchant_repository_impl.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/settlement/data/settlement_repository_impl.dart';
import 'package:khata_flow/features/settlement/domain/settlement_status.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  late AppDatabase db;
  late MerchantRepositoryImpl merchantRepository;
  late LedgerRepositoryImpl ledgerRepository;
  late Merchant merchantA;
  late Merchant merchantB;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    merchantRepository = MerchantRepositoryImpl(db);
    ledgerRepository = LedgerRepositoryImpl(db);

    merchantA = await merchantRepository.createMerchant(
      const CreateMerchantInput(
        name: 'Sharma Kirana',
        category: MerchantCategory.grocery,
        upiVpa: 'sharma@upi',
      ),
    );

    merchantB = await merchantRepository.createMerchant(
      const CreateMerchantInput(
        name: 'Verma Laundry',
        category: MerchantCategory.laundry,
        upiVpa: 'verma@upi',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('LedgerRepository Tests', () {
    test('creates purchase and enqueues sync queue entry atomically', () async {
      final now = DateTime.now();
      final purchase = await ledgerRepository.addPurchase(
        CreatePurchaseInput(
          merchantId: merchantA.id,
          amountPaise: 12000, // ₹120.00
          note: 'Bread & Eggs',
          category: 'Groceries',
          purchaseDate: now,
        ),
      );

      expect(purchase.id, isNotEmpty);
      expect(purchase.merchantId, merchantA.id);
      expect(purchase.amountPaise, 12000);
      expect(purchase.note, 'Bread & Eggs');
      expect(purchase.category, 'Groceries');

      // Check sync queue outbox
      final queueItems = await db.syncQueueDao.getPendingItems();
      // 2 merchant creations + 1 purchase creation
      expect(queueItems.length, 3);
      final purchaseQueueItem = queueItems.firstWhere((q) => q.entityId == purchase.id);
      expect(purchaseQueueItem.entityType, SyncEntityType.purchase.toDbValue());
      expect(purchaseQueueItem.operation, SyncOperation.upsert.toDbValue());
    });

    test('validates purchase amount, note, and merchant existence', () async {
      final now = DateTime.now();

      // Zero/Negative amount
      expect(
        () => ledgerRepository.addPurchase(
          CreatePurchaseInput(
            merchantId: merchantA.id,
            amountPaise: 0,
            note: 'Milk',
            purchaseDate: now,
          ),
        ),
        throwsA(isA<InvalidAmountException>()),
      );

      // Empty note
      expect(
        () => ledgerRepository.addPurchase(
          CreatePurchaseInput(
            merchantId: merchantA.id,
            amountPaise: 5000,
            note: '',
            purchaseDate: now,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      // Non-existent merchant
      expect(
        () => ledgerRepository.addPurchase(
          CreatePurchaseInput(
            merchantId: 'non-existent-uuid',
            amountPaise: 5000,
            note: 'Milk',
            purchaseDate: now,
          ),
        ),
        throwsA(isA<MerchantNotFoundException>()),
      );
    });

    test('tracks multiple purchases with independent balances across merchants', () async {
      final now = DateTime.now();

      // Merchant A purchases: ₹120 (12000) + ₹450 (45000) = ₹570 (57000 paise)
      await ledgerRepository.addPurchase(
        CreatePurchaseInput(
          merchantId: merchantA.id,
          amountPaise: 12000,
          note: 'Bread & Eggs',
          purchaseDate: now,
        ),
      );
      await ledgerRepository.addPurchase(
        CreatePurchaseInput(
          merchantId: merchantA.id,
          amountPaise: 45000,
          note: 'Vegetables',
          purchaseDate: now.add(const Duration(hours: 1)),
        ),
      );

      // Merchant B purchases: ₹250 (25000)
      await ledgerRepository.addPurchase(
        CreatePurchaseInput(
          merchantId: merchantB.id,
          amountPaise: 25000,
          note: 'Dry Cleaning 2 shirts',
          purchaseDate: now,
        ),
      );

      // Merchant A balance
      final balanceA = await ledgerRepository.getOutstandingAmount(merchantA.id);
      expect(balanceA, 57000);

      // Merchant B balance
      final balanceB = await ledgerRepository.getOutstandingAmount(merchantB.id);
      expect(balanceB, 25000);

      // Total Outstanding across all merchants = ₹570 + ₹250 = ₹820 (82000 paise)
      final totalOutstanding = await ledgerRepository.getTotalOutstanding();
      expect(totalOutstanding, 82000);

      // Verify list retrieval
      final purchasesA = await ledgerRepository.getPurchases(merchantA.id);
      expect(purchasesA.length, 2);
      expect(purchasesA.first.note, 'Vegetables'); // Reverse chronological
    });

    test('M4.1 Core Loop: ₹100 + ₹200 + ₹300 = ₹600, settle ₹600 -> outstanding ₹0, purchases preserved as settled', () async {
      final settlementRepository = SettlementRepositoryImpl(db);
      final now = DateTime.now();

      // 1. Add 3 purchases for Merchant A
      final p1 = await ledgerRepository.addPurchase(
        CreatePurchaseInput(
          merchantId: merchantA.id,
          amountPaise: 10000, // ₹100
          note: 'Milk',
          purchaseDate: now,
        ),
      );
      final p2 = await ledgerRepository.addPurchase(
        CreatePurchaseInput(
          merchantId: merchantA.id,
          amountPaise: 20000, // ₹200
          note: 'Groceries',
          purchaseDate: now.add(const Duration(minutes: 10)),
        ),
      );
      final p3 = await ledgerRepository.addPurchase(
        CreatePurchaseInput(
          merchantId: merchantA.id,
          amountPaise: 30000, // ₹300
          note: 'Snacks',
          purchaseDate: now.add(const Duration(minutes: 20)),
        ),
      );

      // Add 1 purchase for Merchant B to test isolation
      await ledgerRepository.addPurchase(
        CreatePurchaseInput(
          merchantId: merchantB.id,
          amountPaise: 15000, // ₹150
          note: 'Laundry',
          purchaseDate: now,
        ),
      );

      // 2. Verify outstanding dues before settlement
      var outstandingA = await ledgerRepository.getOutstandingAmount(merchantA.id);
      expect(outstandingA, 60000); // ₹600.00
      var outstandingB = await ledgerRepository.getOutstandingAmount(merchantB.id);
      expect(outstandingB, 15000); // ₹150.00
      var totalOutstanding = await ledgerRepository.getTotalOutstanding();
      expect(totalOutstanding, 75000); // ₹750.00

      // Verify purchases before settlement have isSettled = false
      var purchasesA = await ledgerRepository.getPurchases(merchantA.id);
      expect(purchasesA.length, 3);
      expect(purchasesA.every((p) => !p.isSettled), true);

      // 3. Initiate and confirm settlement for ₹600
      final settlement = await settlementRepository.initiateSettlement(
        merchantId: merchantA.id,
        purchaseIds: [p1.id, p2.id, p3.id],
      );
      expect(settlement.amountPaise, 60000);

      await settlementRepository.markSettlementSettled(
        settlementId: settlement.id,
        utr: '425612345678',
        transactionId: 'TXN998877',
      );

      // 4. Verify outstanding dues after settlement
      outstandingA = await ledgerRepository.getOutstandingAmount(merchantA.id);
      expect(outstandingA, 0); // ₹0.00

      // Merchant B must remain completely unaffected
      outstandingB = await ledgerRepository.getOutstandingAmount(merchantB.id);
      expect(outstandingB, 15000); // ₹150.00

      totalOutstanding = await ledgerRepository.getTotalOutstanding();
      expect(totalOutstanding, 15000); // ₹150.00

      // 5. Verify historical purchases are NOT deleted and are marked isSettled = true
      purchasesA = await ledgerRepository.getPurchases(merchantA.id);
      expect(purchasesA.length, 3);
      expect(purchasesA.every((p) => p.isSettled), true);

      // Verify unsettled purchases query returns empty for Merchant A
      final unsettledA = await ledgerRepository.getUnsettledPurchases(merchantA.id);
      expect(unsettledA.isEmpty, true);

      // Verify settlement history stream contains the settlement with linked items
      final settlementsA = await settlementRepository.watchSettlementsForMerchant(merchantA.id).first;
      expect(settlementsA.length, 1);
      expect(settlementsA.first.amountPaise, 60000);
      expect(settlementsA.first.status, SettlementStatus.settled);
      expect(settlementsA.first.utr, '425612345678');
      expect(settlementsA.first.items.length, 3);
    });
  });
}

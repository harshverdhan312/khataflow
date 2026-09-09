import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/errors/app_exceptions.dart';
import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/features/ledger/data/ledger_repository_impl.dart';
import 'package:khata_flow/features/ledger/domain/purchase.dart';
import 'package:khata_flow/features/merchant/data/merchant_repository_impl.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
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
  });
}

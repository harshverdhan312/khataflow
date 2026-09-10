import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/features/settlement/data/settlement_repository_impl.dart';
import 'package:khata_flow/features/settlement/domain/settlement_status.dart';

void main() {
  late AppDatabase db;
  late SettlementRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SettlementRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SettlementRepositoryImpl.getSettlementReceipt', () {
    const merchantId = 'merchant-123';
    const settlementId = 'settlement-456';
    const purchaseId1 = 'purchase-1';
    const purchaseId2 = 'purchase-2';
    final now = DateTime(2026, 9, 10, 14, 30).millisecondsSinceEpoch;

    setUp(() async {
      // Seed merchant
      await db.merchantDao.insertMerchant(
        MerchantsCompanion.insert(
          id: merchantId,
          name: 'Gupta General Store',
          category: 'Grocery',
          upiVpa: 'gupta@upi',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed purchases
      await db.purchaseDao.insertPurchase(
        PurchasesCompanion.insert(
          id: purchaseId1,
          merchantId: merchantId,
          amountPaise: 50000, // ₹500.00
          note: 'Milk & Bread',
          category: const Value('Dairy'),
          purchaseDate: now - 86400000,
          createdAt: now - 86400000,
          updatedAt: now - 86400000,
        ),
      );

      await db.purchaseDao.insertPurchase(
        PurchasesCompanion.insert(
          id: purchaseId2,
          merchantId: merchantId,
          amountPaise: 75000, // ₹750.00
          note: 'Rice & Oil',
          category: const Value('Grocery'),
          purchaseDate: now - 43200000,
          createdAt: now - 43200000,
          updatedAt: now - 43200000,
        ),
      );
    });

    test('returns full SettlementReceipt for a SETTLED settlement with linked items and metadata', () async {
      await db.settlementDao.insertSettlementWithItems(
        settlement: SettlementsCompanion.insert(
          id: settlementId,
          merchantId: merchantId,
          amountPaise: 125000, // ₹1,250.00
          status: SettlementStatus.settled.toDbValue(),
          initiatedAt: now,
          completedAt: Value(now + 60000),
          createdAt: now,
          updatedAt: now + 60000,
          utr: const Value('UTR1234567890'),
          transactionId: const Value('TXN9876543210'),
        ),
        items: [
          SettlementItemsCompanion.insert(
            settlementId: settlementId,
            purchaseId: purchaseId1,
            amountPaise: 50000,
          ),
          SettlementItemsCompanion.insert(
            settlementId: settlementId,
            purchaseId: purchaseId2,
            amountPaise: 75000,
          ),
        ],
      );

      final receipt = await repository.getSettlementReceipt(settlementId);

      expect(receipt, isNotNull);
      expect(receipt!.settlementId, equals(settlementId));
      expect(receipt.merchantId, equals(merchantId));
      expect(receipt.merchantName, equals('Gupta General Store'));
      expect(receipt.merchantUpiVpa, equals('gupta@upi'));
      expect(receipt.amountPaise, equals(125000));
      expect(receipt.totalSettledPaise, equals(125000));
      expect(receipt.status, equals('SETTLED'));
      expect(receipt.utr, equals('UTR1234567890'));
      expect(receipt.transactionId, equals('TXN9876543210'));
      expect(receipt.items.length, equals(2));

      expect(receipt.items[0].purchaseId, equals(purchaseId1));
      expect(receipt.items[0].note, equals('Milk & Bread'));
      expect(receipt.items[0].amountPaise, equals(50000));
      expect(receipt.items[0].category, equals('Dairy'));

      expect(receipt.items[1].purchaseId, equals(purchaseId2));
      expect(receipt.items[1].note, equals('Rice & Oil'));
      expect(receipt.items[1].amountPaise, equals(75000));
      expect(receipt.items[1].category, equals('Grocery'));
    });

    test('omits optional UTR and transactionId when absent', () async {
      await db.settlementDao.insertSettlementWithItems(
        settlement: SettlementsCompanion.insert(
          id: settlementId,
          merchantId: merchantId,
          amountPaise: 50000,
          status: SettlementStatus.settled.toDbValue(),
          initiatedAt: now,
          completedAt: Value(now + 60000),
          createdAt: now,
          updatedAt: now + 60000,
        ),
        items: [
          SettlementItemsCompanion.insert(
            settlementId: settlementId,
            purchaseId: purchaseId1,
            amountPaise: 50000,
          ),
        ],
      );

      final receipt = await repository.getSettlementReceipt(settlementId);

      expect(receipt, isNotNull);
      expect(receipt!.utr, isNull);
      expect(receipt.transactionId, isNull);
    });

    test('handles empty linked items gracefully without crashing', () async {
      await db.settlementDao.insertSettlementWithItems(
        settlement: SettlementsCompanion.insert(
          id: settlementId,
          merchantId: merchantId,
          amountPaise: 10000,
          status: SettlementStatus.settled.toDbValue(),
          initiatedAt: now,
          completedAt: Value(now + 60000),
          createdAt: now,
          updatedAt: now + 60000,
        ),
        items: [],
      );

      final receipt = await repository.getSettlementReceipt(settlementId);

      expect(receipt, isNotNull);
      expect(receipt!.items, isEmpty);
      expect(receipt.amountPaise, equals(10000));
      expect(receipt.totalSettledPaise, equals(10000));
    });

    test('returns null for FAILED settlement', () async {
      await db.settlementDao.insertSettlementWithItems(
        settlement: SettlementsCompanion.insert(
          id: settlementId,
          merchantId: merchantId,
          amountPaise: 50000,
          status: SettlementStatus.failed.toDbValue(),
          initiatedAt: now,
          completedAt: Value(now + 60000),
          createdAt: now,
          updatedAt: now + 60000,
        ),
        items: [
          SettlementItemsCompanion.insert(
            settlementId: settlementId,
            purchaseId: purchaseId1,
            amountPaise: 50000,
          ),
        ],
      );

      final receipt = await repository.getSettlementReceipt(settlementId);
      expect(receipt, isNull);
    });

    test('returns null for UNKNOWN settlement', () async {
      await db.settlementDao.insertSettlementWithItems(
        settlement: SettlementsCompanion.insert(
          id: settlementId,
          merchantId: merchantId,
          amountPaise: 50000,
          status: SettlementStatus.unknown.toDbValue(),
          initiatedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          SettlementItemsCompanion.insert(
            settlementId: settlementId,
            purchaseId: purchaseId1,
            amountPaise: 50000,
          ),
        ],
      );

      final receipt = await repository.getSettlementReceipt(settlementId);
      expect(receipt, isNull);
    });

    test('returns null for UPI_LAUNCHED settlement', () async {
      await db.settlementDao.insertSettlementWithItems(
        settlement: SettlementsCompanion.insert(
          id: settlementId,
          merchantId: merchantId,
          amountPaise: 50000,
          status: SettlementStatus.upiLaunched.toDbValue(),
          initiatedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          SettlementItemsCompanion.insert(
            settlementId: settlementId,
            purchaseId: purchaseId1,
            amountPaise: 50000,
          ),
        ],
      );

      final receipt = await repository.getSettlementReceipt(settlementId);
      expect(receipt, isNull);
    });

    test('returns null for INITIATED settlement', () async {
      await db.settlementDao.insertSettlementWithItems(
        settlement: SettlementsCompanion.insert(
          id: settlementId,
          merchantId: merchantId,
          amountPaise: 50000,
          status: SettlementStatus.initiated.toDbValue(),
          initiatedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        items: [
          SettlementItemsCompanion.insert(
            settlementId: settlementId,
            purchaseId: purchaseId1,
            amountPaise: 50000,
          ),
        ],
      );

      final receipt = await repository.getSettlementReceipt(settlementId);
      expect(receipt, isNull);
    });

    test('returns null for nonexistent settlement ID', () async {
      final receipt = await repository.getSettlementReceipt('non-existent-id');
      expect(receipt, isNull);
    });
  });
}

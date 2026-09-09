import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:khata_flow/features/ledger/data/ledger_repository_impl.dart';
import 'package:khata_flow/features/ledger/domain/purchase.dart';
import 'package:khata_flow/features/merchant/data/merchant_repository_impl.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';

void main() {
  late AppDatabase db;
  late MerchantRepositoryImpl merchantRepo;
  late LedgerRepositoryImpl ledgerRepo;
  late DashboardRepositoryImpl dashboardRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    merchantRepo = MerchantRepositoryImpl(db);
    ledgerRepo = LedgerRepositoryImpl(db);
    dashboardRepo = DashboardRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DashboardRepository Tests', () {
    test('returns empty dashboard summary when no merchants exist', () async {
      final summary = await dashboardRepo.getDashboardSummary();
      expect(summary.totalOutstandingPaise, 0);
      expect(summary.merchantSummaries, isEmpty);
    });

    test('calculates merchant summaries and total outstanding reactively', () async {
      final m1 = await merchantRepo.createMerchant(
        const CreateMerchantInput(
          name: 'Sharma Kirana',
          category: MerchantCategory.grocery,
          upiVpa: 'sharma@upi',
        ),
      );

      final m2 = await merchantRepo.createMerchant(
        const CreateMerchantInput(
          name: 'Verma Laundry',
          category: MerchantCategory.laundry,
          upiVpa: 'verma@upi',
        ),
      );

      await ledgerRepo.addPurchase(
        CreatePurchaseInput(
          merchantId: m1.id,
          amountPaise: 12000,
          note: 'Bread & Eggs',
          purchaseDate: DateTime.now(),
        ),
      );

      await ledgerRepo.addPurchase(
        CreatePurchaseInput(
          merchantId: m2.id,
          amountPaise: 35000,
          note: 'Blanket cleaning',
          purchaseDate: DateTime.now(),
        ),
      );

      final summary = await dashboardRepo.getDashboardSummary();
      expect(summary.totalOutstandingPaise, 47000); // ₹120 + ₹350 = ₹470 (47000 paise)
      expect(summary.merchantSummaries.length, 2);

      final sharma = summary.merchantSummaries.firstWhere((s) => s.merchant.id == m1.id);
      expect(sharma.outstandingPaise, 12000);
      expect(sharma.lastActiveAt, isNotNull);

      final verma = summary.merchantSummaries.firstWhere((s) => s.merchant.id == m2.id);
      expect(verma.outstandingPaise, 35000);
    });
  });
}

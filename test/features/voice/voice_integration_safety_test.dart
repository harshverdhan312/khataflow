import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/services/voice_service.dart';
import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/features/ledger/data/ledger_repository_impl.dart';
import 'package:khata_flow/features/ledger/domain/purchase.dart';
import 'package:khata_flow/features/merchant/data/merchant_repository_impl.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/settlement/data/settlement_repository_impl.dart';
import 'package:khata_flow/features/voice/data/deterministic_voice_command_parser.dart';
import 'package:khata_flow/features/voice/domain/merchant_resolver.dart';
import 'package:khata_flow/features/voice/domain/voice_transcript.dart';
import 'package:khata_flow/features/voice/presentation/voice_controller.dart';
import 'package:khata_flow/features/voice/presentation/voice_state.dart';

class TestVoiceService implements VoiceService {
  @override
  bool get isListening => false;
  @override
  bool get isAvailable => true;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> startListening({required void Function(String text, bool isFinal) onResult, required void Function(String error) onError, String? localeId}) async {}
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> cancelListening() async {}
}

void main() {
  group('Voice Ledger End-to-End Safety & Integration Tests (Step 21)', () {
    late AppDatabase db;
    late MerchantRepositoryImpl merchantRepo;
    late LedgerRepositoryImpl ledgerRepo;
    late SettlementRepositoryImpl settlementRepo;
    late VoiceController controller;
    late Merchant testMerchant;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      merchantRepo = MerchantRepositoryImpl(db);
      ledgerRepo = LedgerRepositoryImpl(db);
      settlementRepo = SettlementRepositoryImpl(db);

      // Seed an active merchant in SQLite
      testMerchant = await merchantRepo.createMerchant(
        const CreateMerchantInput(
          name: 'Sharma General Store',
          category: MerchantCategory.grocery,
          phone: '9876543210',
          upiVpa: 'sharma@upi',
        ),
      );

      controller = VoiceController(
        voiceService: TestVoiceService(),
        parser: const DeterministicVoiceCommandParser(),
        merchantRepository: merchantRepo,
        ledgerRepository: ledgerRepo,
        settlementRepository: settlementRepo,
        merchantResolver: const MerchantResolver(),
      );
    });

    tearDown(() async {
      controller.dispose();
      await db.close();
    });

    test('Confirmed purchase flows through parser -> resolver -> confirmation -> SQLite database', () async {
      // 1. Process Voice Transcript
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Sharma se doodh 60 aur bread 40 liya',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.resolvedMerchant?.id, equals(testMerchant.id));

      // 2. Explicit User Confirmation
      final success = await controller.executeConfirmedCommand();
      expect(success, isTrue);
      expect(controller.state.status, equals(VoiceStatus.completed));

      // 3. Verify SQLite DB state
      final purchases = await ledgerRepo.getPurchases(testMerchant.id);
      expect(purchases.length, equals(2));
      expect(purchases.map((p) => p.note), containsAll(['Doodh', 'Bread']));
      expect(purchases.map((p) => p.amountPaise), containsAll([6000, 4000]));

      final outstanding = await ledgerRepo.getOutstandingAmount(testMerchant.id);
      expect(outstanding, equals(10000)); // ₹100.00
    });

    test('Cancelled purchase causes ZERO SQLite database mutations', () async {
      // 1. Process Voice Transcript
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Sharma se doodh 60 liya',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));

      // 2. User Cancels
      controller.cancelCommand();
      expect(controller.state.status, equals(VoiceStatus.idle));

      // 3. Verify DB has no new purchases
      final purchases = await ledgerRepo.getPurchases(testMerchant.id);
      expect(purchases, isEmpty);

      final outstanding = await ledgerRepo.getOutstandingAmount(testMerchant.id);
      expect(outstanding, equals(0));
    });

    test('Confirmed settlement atomically settles dues and updates SQLite database', () async {
      // 1. Existing purchase in SQLite
      await ledgerRepo.addPurchase(
        CreatePurchaseInput(
          merchantId: testMerchant.id,
          amountPaise: 50000,
          note: 'Groceries',
          purchaseDate: DateTime.now(),
        ),
      );

      var outstanding = await ledgerRepo.getOutstandingAmount(testMerchant.id);
      expect(outstanding, equals(50000));

      // 2. Process Settlement Voice Transcript
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Sharma ko 500 de diye ref TXN-101',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));

      // 3. User Confirms Settlement
      final success = await controller.executeConfirmedCommand();
      expect(success, isTrue);
      expect(controller.state.status, equals(VoiceStatus.completed));

      // 4. Verify SQLite outstanding balance is now settled (0)
      outstanding = await ledgerRepo.getOutstandingAmount(testMerchant.id);
      expect(outstanding, equals(0));

      final settlements = await settlementRepo.watchSettlementsForMerchant(testMerchant.id).first;
      expect(settlements.length, equals(1));
      expect(settlements.first.amountPaise, equals(50000));
      expect(settlements.first.utr, equals('TXN-101'));
    });

    test('Cancelled settlement leaves SQLite dues intact', () async {
      // 1. Existing purchase
      await ledgerRepo.addPurchase(
        CreatePurchaseInput(
          merchantId: testMerchant.id,
          amountPaise: 50000,
          note: 'Groceries',
          purchaseDate: DateTime.now(),
        ),
      );

      // 2. Process Settlement Transcript
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Sharma ko 500 de diye',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));

      // 3. User Cancels
      controller.cancelCommand();

      // 4. Verify SQLite dues remain untouched
      final outstanding = await ledgerRepo.getOutstandingAmount(testMerchant.id);
      expect(outstanding, equals(50000));
    });

    test('M5.4 Full Settlement: Confirmed full settlement calculates live dues and settles SQLite database', () async {
      // 1. Add multiple purchases to SQLite
      await ledgerRepo.addPurchase(
        CreatePurchaseInput(
          merchantId: testMerchant.id,
          amountPaise: 40000, // ₹400
          note: 'Provisions',
          purchaseDate: DateTime.now(),
        ),
      );
      await ledgerRepo.addPurchase(
        CreatePurchaseInput(
          merchantId: testMerchant.id,
          amountPaise: 20000, // ₹200
          note: 'Snacks',
          purchaseDate: DateTime.now(),
        ),
      );

      var outstanding = await ledgerRepo.getOutstandingAmount(testMerchant.id);
      expect(outstanding, equals(60000)); // ₹600

      // 2. Process Full Settlement Voice Command
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Sharma ki payment settle kar do',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.outstandingPaiseToSettle, equals(60000));

      // 3. User sets optional payment reference and confirms
      controller.setPendingPaymentReference('CASH-PAID');
      final success = await controller.executeConfirmedCommand();
      expect(success, isTrue);
      expect(controller.state.status, equals(VoiceStatus.completed));

      // 4. Verify SQLite outstanding balance is now 0
      outstanding = await ledgerRepo.getOutstandingAmount(testMerchant.id);
      expect(outstanding, equals(0));

      final settlements = await settlementRepo.watchSettlementsForMerchant(testMerchant.id).first;
      expect(settlements.length, equals(1));
      expect(settlements.first.amountPaise, equals(60000));
      expect(settlements.first.utr, equals('CASH-PAID'));
    });

    test('M5.4 Financial Safety: Stale confirmation race condition is safely blocked at execution time', () async {
      // 1. Initial purchases: Total ₹600
      final p1 = await ledgerRepo.addPurchase(
        CreatePurchaseInput(
          merchantId: testMerchant.id,
          amountPaise: 30000, // ₹300
          note: 'Item 1',
          purchaseDate: DateTime.now(),
        ),
      );
      final p2 = await ledgerRepo.addPurchase(
        CreatePurchaseInput(
          merchantId: testMerchant.id,
          amountPaise: 30000, // ₹300
          note: 'Item 2',
          purchaseDate: DateTime.now(),
        ),
      );

      // 2. Voice command captures and displays ₹600 confirmation
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Sharma ki payment settle kar do',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.outstandingPaiseToSettle, equals(60000));

      // 3. RACE CONDITION SIMULATION:
      // While confirmation is displayed, an external/manual settlement settles all purchases in the DB
      await settlementRepo.recordSettlement(
        merchantId: testMerchant.id,
        purchaseIds: [p1.id, p2.id],
        paymentReference: 'EXTERNAL-SETTLEMENT',
      );

      final currentDbOutstanding = await ledgerRepo.getOutstandingAmount(testMerchant.id);
      expect(currentDbOutstanding, equals(0)); // Outstanding in DB is now 0!

      // 4. User taps confirm on the stale confirmation UI (which showed ₹600)
      final success = await controller.executeConfirmedCommand();

      // Controller must recheck live SQLite DB state, detect 0 outstanding, and abort safely
      expect(success, isFalse);
      expect(controller.state.status, equals(VoiceStatus.error));
      expect(controller.state.errorMessage, contains('No outstanding dues'));

      // Ensure no duplicate or corrupt second settlement occurred
      final allSettlements = await settlementRepo.watchSettlementsForMerchant(testMerchant.id).first;
      expect(allSettlements.length, equals(1)); // Only the external settlement exists
    });

    test('M5.4 Voice Ledger Creation: Creates new merchant in SQLite after explicit confirmation', () async {
      // 1. Process Merchant Creation Transcript
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Rahul sabji wale ka ledger bana do upi rahul@oksbi',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.pendingCategory, equals(MerchantCategory.grocery));
      expect(controller.state.pendingUpiVpa, equals('rahul@oksbi'));

      // 2. Confirm Creation
      final success = await controller.executeConfirmedCommand();
      expect(success, isTrue);
      expect(controller.state.status, equals(VoiceStatus.completed));

      // 3. Verify in SQLite DB
      final merchants = await merchantRepo.getActiveMerchants();
      final created = merchants.firstWhere((m) => m.name == 'Rahul Sabji Wale');
      expect(created.category, equals(MerchantCategory.grocery));
      expect(created.upiVpa, equals('rahul@oksbi'));
      expect(created.isActive, isTrue);
    });

    test('M5.4 Voice Ledger Creation: Exact duplicate merchant creation is blocked', () async {
      // testMerchant 'Sharma General Store' already exists in DB
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Sharma General Store ka ledger bana do',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.error));
      expect(controller.state.errorMessage, contains('already exists'));

      final merchants = await merchantRepo.getActiveMerchants();
      expect(merchants.where((m) => m.name == 'Sharma General Store').length, equals(1));
    });
  });
}

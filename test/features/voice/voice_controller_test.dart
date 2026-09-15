import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/services/voice_service.dart';
import 'package:khata_flow/features/ledger/domain/ledger_repository.dart';
import 'package:khata_flow/features/ledger/domain/purchase.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/merchant/domain/merchant_repository.dart';
import 'package:khata_flow/features/receipt/domain/settlement_receipt.dart';
import 'package:khata_flow/features/settlement/domain/settlement.dart';
import 'package:khata_flow/features/settlement/domain/settlement_repository.dart';
import 'package:khata_flow/features/settlement/domain/settlement_status.dart';
import 'package:khata_flow/features/voice/data/deterministic_voice_command_parser.dart';
import 'package:khata_flow/features/voice/domain/merchant_resolver.dart';
import 'package:khata_flow/features/voice/domain/voice_command.dart';
import 'package:khata_flow/features/voice/domain/voice_transcript.dart';
import 'package:khata_flow/features/voice/presentation/voice_controller.dart';
import 'package:khata_flow/features/voice/presentation/voice_state.dart';

class FakeVoiceService implements VoiceService {
  bool initializeResult = true;
  bool permissionResult = true;
  bool listening = false;
  void Function(String text, bool isFinal)? onResultCallback;
  void Function(String error)? onErrorCallback;
  String? lastLocaleId;

  @override
  bool get isListening => listening;

  @override
  bool get isAvailable => initializeResult;

  @override
  Future<bool> initialize() async => initializeResult;

  @override
  Future<bool> hasPermission() async => permissionResult;

  @override
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String error) onError,
    String? localeId,
  }) async {
    listening = true;
    onResultCallback = onResult;
    onErrorCallback = onError;
    lastLocaleId = localeId;
  }

  @override
  Future<void> stopListening() async {
    listening = false;
  }

  @override
  Future<void> cancelListening() async {
    listening = false;
  }

  void simulateSpeechResult(String text, bool isFinal) {
    onResultCallback?.call(text, isFinal);
  }

  void simulateError(String error) {
    onErrorCallback?.call(error);
  }
}

class FakeMerchantRepository implements MerchantRepository {
  List<Merchant> activeMerchants = [];
  List<Merchant> inactiveMerchants = [];

  @override
  Future<List<Merchant>> getActiveMerchants() async => activeMerchants;

  @override
  Future<Merchant?> getMerchantById(String id) async =>
      [...activeMerchants, ...inactiveMerchants].where((m) => m.id == id).firstOrNull;

  @override
  Future<Merchant> createMerchant(CreateMerchantInput input) async {
    final merchant = Merchant(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      name: input.name,
      category: input.category,
      phone: input.phone,
      upiVpa: input.upiVpa,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    activeMerchants.add(merchant);
    return merchant;
  }

  @override
  Future<void> deactivateMerchant(String merchantId) async => throw UnimplementedError();

  @override
  Future<void> reactivateMerchant(String merchantId) async => throw UnimplementedError();

  @override
  Future<void> updateMerchant(Merchant merchant) async => throw UnimplementedError();

  @override
  Stream<List<Merchant>> watchActiveMerchants() => Stream.value(activeMerchants);

  @override
  Stream<List<Merchant>> watchInactiveMerchants() => Stream.value(inactiveMerchants);
}

class FakeLedgerRepository implements LedgerRepository {
  final List<Purchase> purchases = [];

  @override
  Future<Purchase> addPurchase(CreatePurchaseInput input) async {
    final purchase = Purchase(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}_${purchases.length}',
      merchantId: input.merchantId,
      amountPaise: input.amountPaise,
      note: input.note,
      category: input.category,
      purchaseDate: input.purchaseDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    purchases.add(purchase);
    return purchase;
  }

  @override
  Future<List<Purchase>> getPurchases(String merchantId) async =>
      purchases.where((p) => p.merchantId == merchantId).toList();

  @override
  Future<List<Purchase>> getUnsettledPurchases(String merchantId) async =>
      purchases.where((p) => p.merchantId == merchantId && !p.isSettled).toList();

  @override
  Future<int> getOutstandingAmount(String merchantId) async => purchases
      .where((p) => p.merchantId == merchantId && !p.isSettled)
      .fold<int>(0, (sum, p) => sum + p.amountPaise);

  @override
  Future<int> getTotalOutstanding() async => purchases
      .where((p) => !p.isSettled)
      .fold<int>(0, (sum, p) => sum + p.amountPaise);

  @override
  Stream<int> watchOutstandingAmount(String merchantId) => Stream.value(0);

  @override
  Stream<List<Purchase>> watchPurchases(String merchantId) => Stream.value([]);

  @override
  Stream<int> watchTotalOutstanding() => Stream.value(0);
}

class FakeSettlementRepository implements SettlementRepository {
  final List<Settlement> settlements = [];
  int recordSettlementCallCount = 0;

  @override
  Future<Settlement> recordSettlement({
    required String merchantId,
    required List<String> purchaseIds,
    String? paymentReference,
  }) async {
    recordSettlementCallCount++;
    final settlement = Settlement(
      id: 's_${DateTime.now().millisecondsSinceEpoch}',
      merchantId: merchantId,
      amountPaise: 50000,
      status: SettlementStatus.settled,
      utr: paymentReference,
      initiatedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    settlements.add(settlement);
    return settlement;
  }

  @override
  Future<List<Settlement>> getAllSettlements() async => settlements;

  @override
  Future<Settlement?> getSettlementById(String settlementId) async => null;

  @override
  Future<SettlementReceipt?> getSettlementReceipt(String settlementId) async => null;

  @override
  Future<List<String>> getUnresolvedPurchaseIds(String merchantId) async => [];

  @override
  Future<List<Settlement>> getUnresolvedSettlements({String? merchantId}) async => [];

  @override
  Future<bool> hasUnresolvedSettlementForMerchant(String merchantId) async => false;

  @override
  Future<Settlement> initiateSettlement({
    required String merchantId,
    required List<String> purchaseIds,
  }) async => throw UnimplementedError();

  @override
  Future<void> markSettlementFailed({required String settlementId, required String reason}) async {}

  @override
  Future<void> markSettlementSettled({required String settlementId, String? transactionId, String? utr}) async {}

  @override
  Future<void> markSettlementUnknown({required String settlementId}) async {}

  @override
  Future<void> updateSettlementStatus({
    required String settlementId,
    required SettlementStatus status,
    String? transactionId,
    String? utr,
  }) async {}

  @override
  Stream<List<Settlement>> watchAllSettlements() => Stream.value([]);

  @override
  Stream<List<Settlement>> watchSettlementsForMerchant(String merchantId) => Stream.value([]);
}

void main() {
  group('VoiceController Unit Tests (M5.3 Pipeline)', () {
    late FakeVoiceService fakeVoiceService;
    late FakeMerchantRepository fakeMerchantRepo;
    late FakeLedgerRepository fakeLedgerRepo;
    late FakeSettlementRepository fakeSettlementRepo;
    late VoiceController controller;

    final sharmaStore = Merchant(
      id: 'm_sharma',
      name: 'Sharma General Store',
      category: MerchantCategory.grocery,
      phone: '9876543210',
      upiVpa: 'sharma@upi',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final sharmaSweets = Merchant(
      id: 'm_sharma_sweets',
      name: 'Sharma Sweets',
      category: MerchantCategory.other,
      phone: '9876543211',
      upiVpa: 'sharmasweets@upi',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final guptaStore = Merchant(
      id: 'm_gupta',
      name: 'Gupta Traders',
      category: MerchantCategory.grocery,
      phone: '9876543212',
      upiVpa: 'gupta@upi',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      fakeVoiceService = FakeVoiceService();
      fakeMerchantRepo = FakeMerchantRepository();
      fakeLedgerRepo = FakeLedgerRepository();
      fakeSettlementRepo = FakeSettlementRepository();

      fakeMerchantRepo.activeMerchants = [sharmaStore, guptaStore];

      controller = VoiceController(
        voiceService: fakeVoiceService,
        parser: const DeterministicVoiceCommandParser(),
        merchantRepository: fakeMerchantRepo,
        ledgerRepository: fakeLedgerRepo,
        settlementRepository: fakeSettlementRepo,
        merchantResolver: const MerchantResolver(),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state is idle with default en_IN locale and null state', () {
      expect(controller.state.status, equals(VoiceStatus.idle));
      expect(controller.state.selectedLocale, equals('en_IN'));
      expect(controller.state.transcript, isNull);
      expect(controller.state.command, isNull);
      expect(controller.state.resolvedMerchant, isNull);
    });

    test('listening -> partial transcript updates UI only without parsing', () async {
      await controller.startListening();

      fakeVoiceService.simulateSpeechResult('Sharma se doodh', false);

      expect(controller.state.status, equals(VoiceStatus.listening));
      expect(controller.state.transcript?.text, equals('Sharma se doodh'));
      expect(controller.state.command, isNull);
    });

    test('final transcript -> parses and resolves merchant -> status is commandReady', () async {
      await controller.startListening();

      fakeVoiceService.simulateSpeechResult('Gupta se doodh 60 liya', true);

      // Allow async resolution
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.command, isA<AddPurchaseCommand>());
      expect(controller.state.resolvedMerchant?.id, equals('m_gupta'));
    });

    test('parse failure transitions to error state', () async {
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Hello what is the weather',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.error));
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.command, isNull);
    });

    test('ambiguous merchant puts controller into ambiguousMerchant state', () async {
      fakeMerchantRepo.activeMerchants = [sharmaStore, sharmaSweets];

      await controller.processTranscript(
        VoiceTranscript(
          text: 'Sharma se doodh 60 liya',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.ambiguousMerchant));
      expect(controller.state.candidateMerchants?.length, equals(2));
      expect(controller.state.resolvedMerchant, isNull);

      // User selects candidate merchant
      controller.selectCandidateMerchant(sharmaSweets);

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.resolvedMerchant?.id, equals('m_sharma_sweets'));
      expect(controller.state.candidateMerchants, isNull);
    });

    test('cancelCommand clears state and produces ZERO mutations', () async {
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Gupta se doodh 60 liya',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));

      // Cancel command
      controller.cancelCommand();

      expect(controller.state.status, equals(VoiceStatus.idle));
      expect(controller.state.command, isNull);
      expect(controller.state.resolvedMerchant, isNull);
      expect(fakeLedgerRepo.purchases, isEmpty);
      expect(fakeSettlementRepo.settlements, isEmpty);
    });

    test('executeConfirmedCommand adds purchase items to ledger repository exactly once', () async {
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Gupta se doodh 60 aur bread 40 liya',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));

      final success = await controller.executeConfirmedCommand();

      expect(success, isTrue);
      expect(controller.state.status, equals(VoiceStatus.completed));
      expect(fakeLedgerRepo.purchases.length, equals(2));
      expect(fakeLedgerRepo.purchases[0].merchantId, equals('m_gupta'));
      expect(fakeLedgerRepo.purchases[0].amountPaise, equals(6000));
      expect(fakeLedgerRepo.purchases[1].amountPaise, equals(4000));
    });

    test('executeConfirmedCommand records settlement when dues exist', () async {
      // Add existing unsettled purchase
      await fakeLedgerRepo.addPurchase(
        CreatePurchaseInput(
          merchantId: 'm_gupta',
          amountPaise: 50000,
          note: 'Groceries',
          purchaseDate: DateTime.now(),
        ),
      );

      await controller.processTranscript(
        VoiceTranscript(
          text: 'Gupta ko 500 de diye',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));

      final success = await controller.executeConfirmedCommand();

      expect(success, isTrue);
      expect(controller.state.status, equals(VoiceStatus.completed));
      expect(fakeSettlementRepo.recordSettlementCallCount, equals(1));
    });

    group('M5.4 Voice Actions: SettleMerchantCommand', () {
      test('resolves merchant and fetches live outstanding amount', () async {
        await fakeLedgerRepo.addPurchase(
          CreatePurchaseInput(
            merchantId: 'm_gupta',
            amountPaise: 85000, // ₹850.00
            note: 'Provisions',
            purchaseDate: DateTime.now(),
          ),
        );

        await controller.processTranscript(
          VoiceTranscript(
            text: 'Gupta ki payment settle kar do',
            locale: 'en_IN',
            isFinal: true,
            capturedAt: DateTime.now(),
          ),
        );

        expect(controller.state.status, equals(VoiceStatus.commandReady));
        expect(controller.state.command, isA<SettleMerchantCommand>());
        expect(controller.state.resolvedMerchant?.id, equals('m_gupta'));
        expect(controller.state.outstandingPaiseToSettle, equals(85000));
      });

      test('executeConfirmedCommand executes full settlement using existing atomic recordSettlement', () async {
        await fakeLedgerRepo.addPurchase(
          CreatePurchaseInput(
            merchantId: 'm_gupta',
            amountPaise: 85000,
            note: 'Provisions',
            purchaseDate: DateTime.now(),
          ),
        );

        await controller.processTranscript(
          VoiceTranscript(
            text: 'Gupta ki payment settle kar do',
            locale: 'en_IN',
            isFinal: true,
            capturedAt: DateTime.now(),
          ),
        );

        controller.setPendingPaymentReference('REF-BANK-123');
        expect(controller.state.pendingPaymentReference, equals('REF-BANK-123'));

        final success = await controller.executeConfirmedCommand();

        expect(success, isTrue);
        expect(controller.state.status, equals(VoiceStatus.completed));
        expect(fakeSettlementRepo.recordSettlementCallCount, equals(1));
        expect(fakeSettlementRepo.settlements.last.utr, equals('REF-BANK-123'));
      });

      test('executeConfirmedCommand safely aborts if outstanding is 0 at execution time', () async {
        // No purchases added, outstanding is 0
        await controller.processTranscript(
          VoiceTranscript(
            text: 'Gupta ki payment settle kar do',
            locale: 'en_IN',
            isFinal: true,
            capturedAt: DateTime.now(),
          ),
        );

        expect(controller.state.status, equals(VoiceStatus.commandReady));
        expect(controller.state.outstandingPaiseToSettle, equals(0));

        final success = await controller.executeConfirmedCommand();

        expect(success, isFalse);
        expect(controller.state.status, equals(VoiceStatus.error));
        expect(controller.state.errorMessage, contains('No outstanding dues'));
        expect(fakeSettlementRepo.recordSettlementCallCount, equals(0));
      });
    });

    group('M5.4 Voice Actions: CreateMerchantCommand', () {
      test('blocks creation if exact merchant match already exists', () async {
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
        expect(controller.state.resolvedMerchant, isNull);
      });

      test('disambiguates when potential matches exist and prevents duplicate on candidate selection', () async {
        fakeMerchantRepo.activeMerchants = [sharmaStore, sharmaSweets];

        await controller.processTranscript(
          VoiceTranscript(
            text: 'Sharma ka ledger bana do',
            locale: 'en_IN',
            isFinal: true,
            capturedAt: DateTime.now(),
          ),
        );

        expect(controller.state.status, equals(VoiceStatus.ambiguousMerchant));
        expect(controller.state.candidateMerchants?.length, equals(2));

        // User picks existing merchant candidate
        await controller.selectCandidateMerchant(sharmaStore);

        expect(controller.state.status, equals(VoiceStatus.error));
        expect(controller.state.errorMessage, contains('already exists'));
      });

      test('new merchant with inferred category enters commandReady with pending category', () async {
        await controller.processTranscript(
          VoiceTranscript(
            text: 'Rahul sabji wale ka ledger bana do',
            locale: 'en_IN',
            isFinal: true,
            capturedAt: DateTime.now(),
          ),
        );

        expect(controller.state.status, equals(VoiceStatus.commandReady));
        expect(controller.state.command, isA<CreateMerchantCommand>());
        expect(controller.state.pendingCategory, equals(MerchantCategory.grocery));

        final success = await controller.executeConfirmedCommand();

        expect(success, isTrue);
        expect(controller.state.status, equals(VoiceStatus.completed));
        expect(fakeMerchantRepo.activeMerchants.any((m) => m.name == 'Rahul Sabji Wale'), isTrue);
      });

      test('new merchant without inferred category requires user to select category before execution', () async {
        await controller.processTranscript(
          VoiceTranscript(
            text: 'Rahul ki mobile shop ka ledger bana do',
            locale: 'en_IN',
            isFinal: true,
            capturedAt: DateTime.now(),
          ),
        );

        expect(controller.state.status, equals(VoiceStatus.commandReady));
        expect(controller.state.pendingCategory, isNull);

        // Attempting to execute without category fails safely
        final successWithoutCategory = await controller.executeConfirmedCommand();
        expect(successWithoutCategory, isFalse);
        expect(controller.state.status, equals(VoiceStatus.error));
        expect(controller.state.errorMessage, contains('Please select a category'));

        // Reset to command ready and select category
        controller.setPendingCategory(MerchantCategory.other);
        // Put back in command ready
        await controller.processTranscript(
          VoiceTranscript(
            text: 'Rahul ki mobile shop ka ledger bana do',
            locale: 'en_IN',
            isFinal: true,
            capturedAt: DateTime.now(),
          ),
        );
        controller.setPendingCategory(MerchantCategory.other);

        final success = await controller.executeConfirmedCommand();
        expect(success, isTrue);
        expect(controller.state.status, equals(VoiceStatus.completed));
        expect(fakeMerchantRepo.activeMerchants.any((m) => m.name == 'Rahul Ki Mobile Shop'), isTrue);
      });
    });
  });
}

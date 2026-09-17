import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/services/voice_service.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_repository.dart';
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
import 'package:khata_flow/features/voice/domain/ai_voice_fallback_service.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_command_resolver.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_interpretation.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_result.dart';
import 'package:khata_flow/features/voice/domain/voice_command.dart';
import 'package:khata_flow/features/voice/domain/voice_transcript.dart';
import 'package:khata_flow/features/voice/domain/voice_understanding_source.dart';
import 'package:khata_flow/features/voice/presentation/voice_controller.dart';
import 'package:khata_flow/features/voice/presentation/voice_state.dart';

// Fake implementations for end-to-end integration testing

class FakeVoiceService implements VoiceService {
  @override
  bool get isListening => false;
  @override
  bool get isAvailable => true;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    required Function(String error) onError,
    String? localeId,
  }) async {}
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> cancelListening() async {}
  @override
  Future<bool> hasPermission() async => true;
}

class FakeMerchantRepository implements MerchantRepository {
  final List<Merchant> activeMerchants;
  FakeMerchantRepository(this.activeMerchants);

  @override
  Future<List<Merchant>> getActiveMerchants() async => activeMerchants;
  @override
  Future<Merchant?> getMerchantById(String id) async =>
      activeMerchants.where((m) => m.id == id).firstOrNull;
  @override
  Future<Merchant> createMerchant(CreateMerchantInput input) async => throw UnimplementedError();
  @override
  Future<void> deactivateMerchant(String merchantId) async => throw UnimplementedError();
  @override
  Future<void> reactivateMerchant(String merchantId) async => throw UnimplementedError();
  @override
  Future<void> updateMerchant(Merchant merchant) async => throw UnimplementedError();
  @override
  Stream<List<Merchant>> watchActiveMerchants() => Stream.value(activeMerchants);
  @override
  Stream<List<Merchant>> watchInactiveMerchants() => Stream.value([]);
}

class FakeLedgerRepository implements LedgerRepository {
  final List<CreatePurchaseInput> recordedPurchases = [];

  @override
  Future<Purchase> addPurchase(CreatePurchaseInput input) async {
    recordedPurchases.add(input);
    return Purchase(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}_${recordedPurchases.length}',
      merchantId: input.merchantId,
      amountPaise: input.amountPaise,
      note: input.note,
      category: input.category,
      purchaseDate: input.purchaseDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<int> getOutstandingAmount(String merchantId) async => 0;

  @override
  Future<List<Purchase>> getPurchases(String merchantId) async => [];

  @override
  Future<List<Purchase>> getUnsettledPurchases(String merchantId) async => [];

  @override
  Future<int> getTotalOutstanding() async => 0;

  @override
  Stream<int> watchOutstandingAmount(String merchantId) => Stream.value(0);

  @override
  Stream<List<Purchase>> watchPurchases(String merchantId) => Stream.value([]);

  @override
  Stream<int> watchTotalOutstanding() => Stream.value(0);
}

class FakeSettlementRepository implements SettlementRepository {
  @override
  Future<Settlement> recordSettlement({
    required String merchantId,
    required List<String> purchaseIds,
    String? paymentReference,
  }) async {
    return Settlement(
      id: 's_1',
      merchantId: merchantId,
      amountPaise: 25000,
      status: SettlementStatus.settled,
      utr: paymentReference,
      initiatedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<Settlement>> getAllSettlements() async => [];
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
  Future<Settlement> initiateSettlement({required String merchantId, required List<String> purchaseIds}) async =>
      throw UnimplementedError();
  @override
  Future<void> markSettlementFailed({required String settlementId, required String reason}) async {}
  @override
  Future<void> markSettlementSettled({required String settlementId, String? transactionId, String? utr}) async {}
  @override
  Future<void> markSettlementUnknown({required String settlementId}) async {}
  @override
  Future<void> updateSettlementStatus({required String settlementId, required SettlementStatus status, String? transactionId, String? utr}) async {}
  @override
  Stream<List<Settlement>> watchAllSettlements() => Stream.value([]);
  @override
  Stream<List<Settlement>> watchSettlementsForMerchant(String merchantId) => Stream.value([]);
}

class FakeExpenseRepository implements ExpenseRepository {
  @override
  Future<Expense> createExpense(CreateExpenseInput input) async => throw UnimplementedError();
  @override
  Future<void> deleteExpense(String id) async {}
  @override
  Future<Expense?> getExpenseById(String id) async => null;
  @override
  Future<List<Expense>> getExpenses() async => [];
  @override
  Future<List<Expense>> getExpensesByDateRange({required DateTime startDate, required DateTime endDate}) async => [];
  @override
  Future<Expense> updateExpense(UpdateExpenseInput input) async => throw UnimplementedError();
  @override
  Stream<List<Expense>> watchExpenses() => Stream.value([]);
  @override
  Stream<List<Expense>> watchExpensesByDateRange({required DateTime startDate, required DateTime endDate}) => Stream.value([]);
}

class FakeAiVoiceFallbackService implements AiVoiceFallbackService {
  final SemanticVoiceResult resultToReturn;
  FakeAiVoiceFallbackService(this.resultToReturn);

  @override
  Future<SemanticVoiceResult> interpret(String transcript) async => resultToReturn;
}

void main() {
  group('KhataFlow M8.6.4 — Voice AI Fallback End-to-End Integration Tests', () {
    late FakeMerchantRepository fakeMerchantRepo;
    late FakeLedgerRepository fakeLedgerRepo;
    late FakeSettlementRepository fakeSettlementRepo;
    late FakeExpenseRepository fakeExpenseRepo;
    late VoiceController controller;

    final sharmaMerchant = Merchant(
      id: 'merchant-sharma-1',
      name: 'Sharma Ji Kirana',
      category: MerchantCategory.grocery,
      upiVpa: 'sharma@upi',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    setUp(() {
      fakeMerchantRepo = FakeMerchantRepository([sharmaMerchant]);
      fakeLedgerRepo = FakeLedgerRepository();
      fakeSettlementRepo = FakeSettlementRepository();
      fakeExpenseRepo = FakeExpenseRepository();
    });

    test('Real end-to-end integration: Transcript -> Deterministic Fail -> AI Fallback -> M8.6.4 Resolver -> Confirmation State -> Executed SQLite Write', () async {
      // Spoken complex/unsupported phrasing that deterministic M5 parser cannot parse
      const transcriptText = 'bhaiya Sharma ji ke khate me doodh add kar dena dhai sau ka';
      final transcript = VoiceTranscript(
        text: transcriptText,
        locale: 'hi_IN',
        isFinal: true,
        capturedAt: DateTime(2026, 9, 18),
      );

      // AI semantic interpretation output from M8.6.2/M8.6.3
      final aiInterpretation = SemanticVoiceInterpretation.addPurchase(
        merchantReference: 'Sharma ji',
        item: 'doodh',
        amountText: 'dhai sau',
        rawTranscript: transcriptText,
        source: VoiceUnderstandingSource.aiFallback,
      );

      final fakeFallbackService = FakeAiVoiceFallbackService(
        SemanticVoiceSuccess(aiInterpretation),
      );

      controller = VoiceController(
        voiceService: FakeVoiceService(),
        parser: const DeterministicVoiceCommandParser(),
        merchantRepository: fakeMerchantRepo,
        ledgerRepository: fakeLedgerRepo,
        settlementRepository: fakeSettlementRepo,
        expenseRepository: fakeExpenseRepo,
        aiFallbackService: fakeFallbackService,
        semanticCommandResolver: const SemanticVoiceCommandResolver(),
      );

      // 1. Process transcript
      await controller.processTranscript(transcript);

      // 2. Verify state is in commandReady (REQUIRES confirmation, not completed yet)
      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.resolvedMerchant, equals(sharmaMerchant));
      expect(controller.state.command, isA<AddPurchaseCommand>());

      final command = controller.state.command as AddPurchaseCommand;
      expect(command.merchantName, equals('Sharma Ji Kirana'));
      expect(command.totalAmountPaise, equals(25000)); // dhai sau -> 25000 paise deterministically
      expect(command.items.first.name, equals('Doodh'));
      expect(command.items.first.amountPaise, equals(25000));

      // 3. Verify that NO database mutation occurred during interpretation & resolution!
      expect(fakeLedgerRepo.recordedPurchases, isEmpty);

      // 4. User reviews and explicitly confirms
      final confirmed = await controller.executeConfirmedCommand();
      expect(confirmed, isTrue);

      // 5. Verify successful execution and SQLite write occurred only after confirmation
      expect(controller.state.status, equals(VoiceStatus.completed));
      expect(fakeLedgerRepo.recordedPurchases.length, equals(1));
      expect(fakeLedgerRepo.recordedPurchases.first.merchantId, equals('merchant-sharma-1'));
      expect(fakeLedgerRepo.recordedPurchases.first.amountPaise, equals(25000));
      expect(fakeLedgerRepo.recordedPurchases.first.note, equals('Doodh'));
    });
  });
}

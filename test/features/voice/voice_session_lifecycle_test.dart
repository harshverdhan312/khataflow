import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/services/voice_service.dart';
import 'package:khata_flow/features/expense/domain/expense.dart';
import 'package:khata_flow/features/expense/domain/expense_repository.dart';
import 'package:khata_flow/features/ledger/domain/ledger_repository.dart';
import 'package:khata_flow/features/ledger/domain/purchase.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/merchant/domain/merchant_repository.dart';
import 'package:khata_flow/features/settlement/domain/settlement.dart';
import 'package:khata_flow/features/settlement/domain/settlement_repository.dart';
import 'package:khata_flow/features/settlement/domain/settlement_status.dart';
import 'package:khata_flow/features/voice/data/deterministic_voice_command_parser.dart';
import 'package:khata_flow/features/voice/domain/ai_voice_fallback_service.dart';
import 'package:khata_flow/features/voice/domain/merchant_resolver.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_command_resolver.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_intent.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_interpretation.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_result.dart';
import 'package:khata_flow/features/voice/domain/voice_command.dart';
import 'package:khata_flow/features/voice/domain/voice_transcript.dart';
import 'package:khata_flow/features/voice/domain/voice_understanding_source.dart';
import 'package:khata_flow/features/voice/presentation/voice_controller.dart';
import 'package:khata_flow/features/voice/presentation/voice_state.dart';

// ============================================================================
// MOCKS & TEST DOUBLES
// ============================================================================

class MockVoiceService implements VoiceService {
  bool initialized = true;
  void Function(String text, bool isFinal)? onResultCallback;
  void Function(String error)? onErrorCallback;

  @override
  bool get isListening => false;

  @override
  bool get isAvailable => true;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> initialize() async => initialized;

  @override
  Future<void> startListening({
    String? localeId,
    required void Function(String text, bool isFinal) onResult,
    required void Function(String error) onError,
  }) async {
    onResultCallback = onResult;
    onErrorCallback = onError;
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancelListening() async {}
}

class MockMerchantRepository implements MerchantRepository {
  List<Merchant> merchants = [];

  @override
  Future<List<Merchant>> getActiveMerchants() async =>
      merchants.where((m) => m.isActive).toList();

  @override
  Future<Merchant?> getMerchantById(String id) async =>
      merchants.cast<Merchant?>().firstWhere(
            (m) => m?.id == id,
            orElse: () => null,
          );

  @override
  Future<Merchant> createMerchant(CreateMerchantInput input) async {
    final m = Merchant(
      id: 'm_${merchants.length + 1}',
      name: input.name,
      category: input.category,
      upiVpa: input.upiVpa,
      phone: input.phone,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    merchants.add(m);
    return m;
  }

  @override
  Future<void> updateMerchant(Merchant merchant) async {}

  @override
  Future<void> reactivateMerchant(String merchantId) async {}

  @override
  Future<void> deactivateMerchant(String id) async {
    final idx = merchants.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final old = merchants[idx];
      merchants[idx] = Merchant(
        id: old.id,
        name: old.name,
        category: old.category,
        upiVpa: old.upiVpa,
        phone: old.phone,
        isActive: false,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Stream<List<Merchant>> watchActiveMerchants() => Stream.value(merchants);

  @override
  Stream<List<Merchant>> watchInactiveMerchants() => Stream.value([]);
}

class MockLedgerRepository implements LedgerRepository {
  final List<Purchase> purchases = [];

  @override
  Future<Purchase> addPurchase(CreatePurchaseInput input) async {
    final p = Purchase(
      id: 'p_${purchases.length + 1}',
      merchantId: input.merchantId,
      amountPaise: input.amountPaise,
      note: input.note,
      purchaseDate: input.purchaseDate,
      isSettled: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    purchases.add(p);
    return p;
  }

  @override
  Future<int> getOutstandingAmount(String merchantId) async {
    return purchases
        .where((p) => p.merchantId == merchantId && !p.isSettled)
        .fold<int>(0, (sum, p) => sum + p.amountPaise);
  }

  @override
  Future<List<Purchase>> getUnsettledPurchases(String merchantId) async {
    return purchases
        .where((p) => p.merchantId == merchantId && !p.isSettled)
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSettlementRepository implements SettlementRepository {
  int recordedSettlements = 0;

  @override
  Future<Settlement> recordSettlement({
    required String merchantId,
    required List<String> purchaseIds,
    String? paymentReference,
  }) async {
    recordedSettlements++;
    return Settlement(
      id: 's_1',
      merchantId: merchantId,
      amountPaise: 10000,
      status: SettlementStatus.settled,
      initiatedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockExpenseRepository implements ExpenseRepository {
  final List<Expense> expenses = [];

  @override
  Future<Expense> createExpense(CreateExpenseInput input) async {
    final e = Expense(
      id: 'exp_${expenses.length + 1}',
      amountPaise: input.amountPaise,
      category: input.category,
      note: input.note,
      expenseDate: input.expenseDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expenses.add(e);
    return e;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ControllableAiFallbackService implements AiVoiceFallbackService {
  int callCount = 0;
  Future<SemanticVoiceResult> Function(String transcript)? handler;

  @override
  Future<SemanticVoiceResult> interpret(String transcript) async {
    callCount++;
    if (handler != null) {
      return await handler!(transcript);
    }
    return const SemanticVoiceUnresolved(
      rawTranscript: '',
      failureReason: 'Fallback not configured',
    );
  }
}

void main() {
  group('KhataFlow M8.6.5 — Voice Session Lifecycle & Reliability', () {
    late MockVoiceService voiceService;
    late MockMerchantRepository merchantRepository;
    late MockLedgerRepository ledgerRepository;
    late MockSettlementRepository settlementRepository;
    late MockExpenseRepository expenseRepository;
    late ControllableAiFallbackService aiFallbackService;
    late VoiceController controller;

    final testMerchant = Merchant(
      id: 'm_sharma_1',
      name: 'Sharma General Store',
      category: MerchantCategory.grocery,
      upiVpa: '',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    setUp(() {
      voiceService = MockVoiceService();
      merchantRepository = MockMerchantRepository()..merchants = [testMerchant];
      ledgerRepository = MockLedgerRepository();
      settlementRepository = MockSettlementRepository();
      expenseRepository = MockExpenseRepository();
      aiFallbackService = ControllableAiFallbackService();

      controller = VoiceController(
        voiceService: voiceService,
        parser: const DeterministicVoiceCommandParser(),
        merchantRepository: merchantRepository,
        ledgerRepository: ledgerRepository,
        settlementRepository: settlementRepository,
        expenseRepository: expenseRepository,
        merchantResolver: const MerchantResolver(),
        aiFallbackService: aiFallbackService,
        semanticCommandResolver: const SemanticVoiceCommandResolver(),
      );
    });

    // ========================================================================
    // 1. DETERMINISTIC PATH INVARIANTS
    // ========================================================================

    test(
        'Scenario 1: Deterministic command succeeds -> AI fallback is NEVER called',
        () async {
      final transcript = VoiceTranscript(
        text: 'Sharma se doodh 250 ka liya',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      await controller.processTranscript(transcript);

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.understandingSource,
          equals(VoiceUnderstandingSource.deterministic));
      expect(controller.state.isAiAssisted, isFalse);
      expect(controller.state.command, isA<AddPurchaseCommand>());
      expect(aiFallbackService.callCount, equals(0),
          reason: 'AI service must not be invoked on deterministic success');

      // Confirmation execution
      final confirmed = await controller.executeConfirmedCommand();
      expect(confirmed, isTrue);
      expect(ledgerRepository.purchases.length, equals(1));
      expect(ledgerRepository.purchases.first.amountPaise, equals(25000));
    });

    // ========================================================================
    // 2. AI FALLBACK PATH SUCCESS
    // ========================================================================

    test(
        'Scenario 2: Deterministic parse fails -> AI fallback resolves -> commandReady with AI provenance',
        () async {
      aiFallbackService.handler = (text) async {
        return const SemanticVoiceSuccess(
          SemanticVoiceInterpretation(
            intent: SemanticVoiceIntent.addPurchase,
            merchantReference: 'Sharma',
            amountText: '250',
            item: 'doodh',
            rawTranscript: 'Sharma doodh 250',
          ),
        );
      };

      final transcript = VoiceTranscript(
        text: 'Sharma doodh 250',
        locale: 'hi_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      await controller.processTranscript(transcript);

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.understandingSource,
          equals(VoiceUnderstandingSource.aiFallback));
      expect(controller.state.isAiAssisted, isTrue);
      expect(controller.state.command, isA<AddPurchaseCommand>());
      expect(controller.state.resolvedMerchant?.id, equals('m_sharma_1'));
      expect(aiFallbackService.callCount, equals(1));

      // Execute confirmed command
      final confirmed = await controller.executeConfirmedCommand();
      expect(confirmed, isTrue);
      expect(ledgerRepository.purchases.length, equals(1));
      expect(ledgerRepository.purchases.first.amountPaise, equals(25000));
    });

    // ========================================================================
    // 3. CANCELLATION SAFETY & REQUEST FENCING
    // ========================================================================

    test(
        'Scenario 3: User cancels listening while AI fallback is in progress -> late AI response is ignored',
        () async {
      aiFallbackService.handler = (text) {
        return Future<SemanticVoiceResult>(() async {
          await Future.delayed(const Duration(milliseconds: 50));
          return const SemanticVoiceSuccess(
            SemanticVoiceInterpretation(
              intent: SemanticVoiceIntent.addPurchase,
              merchantReference: 'Sharma',
              amountText: '250',
              item: 'doodh',
              rawTranscript: 'Sharma ji doodh dhai sau',
            ),
          );
        });
      };

      final transcript = VoiceTranscript(
        text: 'Sharma ji doodh dhai sau',
        locale: 'hi_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      // Start processing asynchronously
      final processFuture = controller.processTranscript(transcript);

      // Verify intermediate status is aiFallback
      expect(controller.state.status, equals(VoiceStatus.aiFallback));

      // User immediately cancels listening / command
      await controller.cancelListening();
      expect(controller.state.status, equals(VoiceStatus.idle));
      expect(controller.state.command, isNull);

      // Await processFuture to let late AI response arrive
      await processFuture;

      // State MUST remain idle, no command, no confirmation, zero mutation
      expect(controller.state.status, equals(VoiceStatus.idle));
      expect(controller.state.command, isNull);
      expect(ledgerRepository.purchases, isEmpty);
    });

    test(
        'Scenario 4: User cancels command while in commandReady -> confirmation cancelled -> zero DB mutation',
        () async {
      aiFallbackService.handler = (text) async {
        return const SemanticVoiceSuccess(
          SemanticVoiceInterpretation(
            intent: SemanticVoiceIntent.addPurchase,
            merchantReference: 'Sharma',
            amountText: '100',
            item: 'bread',
            rawTranscript: 'Sharma se bread sau rupaye',
          ),
        );
      };

      final transcript = VoiceTranscript(
        text: 'Sharma se bread sau rupaye',
        locale: 'hi_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      await controller.processTranscript(transcript);
      expect(controller.state.status, equals(VoiceStatus.commandReady));

      // User taps Cancel on confirmation dialog
      controller.cancelCommand();

      expect(controller.state.status, equals(VoiceStatus.idle));
      expect(controller.state.command, isNull);

      // Attempt to execute should fail safely
      final executed = await controller.executeConfirmedCommand();
      expect(executed, isFalse);
      expect(ledgerRepository.purchases, isEmpty);
    });

    test(
        'Scenario 5: Reset during AI processing -> late AI response is discarded',
        () async {
      aiFallbackService.handler = (text) async {
        await Future.delayed(const Duration(milliseconds: 30));
        return const SemanticVoiceSuccess(
          SemanticVoiceInterpretation(
            intent: SemanticVoiceIntent.addPurchase,
            merchantReference: 'Sharma',
            amountText: '500',
            item: 'butter',
            rawTranscript: 'Sharma butter 500',
          ),
        );
      };

      final transcript = VoiceTranscript(
        text: 'Sharma butter 500',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      final future = controller.processTranscript(transcript);
      expect(controller.state.status, equals(VoiceStatus.aiFallback));

      // Controller reset
      controller.reset();
      expect(controller.state.status, equals(VoiceStatus.idle));

      await future;

      expect(controller.state.status, equals(VoiceStatus.idle));
      expect(controller.state.command, isNull);
      expect(ledgerRepository.purchases, isEmpty);
    });

    test(
        'Scenario 6: Stale request protection (Request A starts -> Request B starts -> Response A arrives late)',
        () async {
      // Request A (delayed)
      aiFallbackService.handler = (text) async {
        if (text.contains('Request A')) {
          await Future.delayed(const Duration(milliseconds: 60));
          return const SemanticVoiceSuccess(
            SemanticVoiceInterpretation(
              intent: SemanticVoiceIntent.addPurchase,
              merchantReference: 'Sharma',
              amountText: '100',
              item: 'item A',
              rawTranscript: 'Request A text',
            ),
          );
        } else {
          // Request B (fast)
          return const SemanticVoiceSuccess(
            SemanticVoiceInterpretation(
              intent: SemanticVoiceIntent.addPurchase,
              merchantReference: 'Sharma',
              amountText: '200',
              item: 'item B',
              rawTranscript: 'Request B text',
            ),
          );
        }
      };

      final transcriptA = VoiceTranscript(
        text: 'Request A text',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );
      final transcriptB = VoiceTranscript(
        text: 'Request B text',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      // Start Request A
      final futureA = controller.processTranscript(transcriptA);

      // Start Request B (which supersedes A and increments session ID)
      final futureB = controller.processTranscript(transcriptB);
      await futureB;

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      final cmdB = controller.state.command as AddPurchaseCommand;
      expect(cmdB.items.first.name, equals('Item B'));
      expect(cmdB.totalAmountPaise, equals(20000));

      // Let Request A finish late
      await futureA;

      // State MUST STILL BE Request B, not overwritten by A
      expect(controller.state.status, equals(VoiceStatus.commandReady));
      final cmdFinal = controller.state.command as AddPurchaseCommand;
      expect(cmdFinal.items.first.name, equals('Item B'));
      expect(cmdFinal.totalAmountPaise, equals(20000));
    });

    // ========================================================================
    // 4. AMBIGUOUS MERCHANT & STALE STATE RESOLUTION
    // ========================================================================

    test('Scenario 7: Ambiguous merchant -> candidate selection -> fresh resolution', () async {
      final dairy = Merchant(
        id: 'm_sharma_dairy',
        name: 'Sharma Dairy',
        category: MerchantCategory.milk,
        upiVpa: '',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      merchantRepository.merchants = [testMerchant, dairy];

      aiFallbackService.handler = (text) async {
        return const SemanticVoiceSuccess(
          SemanticVoiceInterpretation(
            intent: SemanticVoiceIntent.addPurchase,
            merchantReference: 'Sharma',
            amountText: '300',
            item: 'paneer',
            rawTranscript: 'Sharma paneer 300',
          ),
        );
      };

      final transcript = VoiceTranscript(
        text: 'Sharma paneer 300',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      await controller.processTranscript(transcript);

      expect(controller.state.status, equals(VoiceStatus.ambiguousMerchant));
      expect(controller.state.candidateMerchants?.length, equals(2));
      expect(controller.state.pendingInterpretation, isNotNull);
      expect(controller.state.command, isNull,
          reason: 'Ambiguity must never store executable command');

      // User selects Sharma Dairy
      await controller.selectCandidateMerchant(dairy);

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.resolvedMerchant?.id, equals('m_sharma_dairy'));
      expect(controller.state.understandingSource,
          equals(VoiceUnderstandingSource.aiFallback));
      expect(controller.state.isAiAssisted, isTrue);

      final confirmed = await controller.executeConfirmedCommand();
      expect(confirmed, isTrue);
      expect(ledgerRepository.purchases.first.merchantId, equals('m_sharma_dairy'));
      expect(ledgerRepository.purchases.first.amountPaise, equals(30000));
    });

    test(
        'Scenario 8: Stale merchant ambiguity protection -> merchant deactivated before selection -> resolution failure',
        () async {
      final dairy = Merchant(
        id: 'm_sharma_dairy',
        name: 'Sharma Dairy',
        category: MerchantCategory.milk,
        upiVpa: '',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      merchantRepository.merchants = [testMerchant, dairy];

      aiFallbackService.handler = (text) async {
        return const SemanticVoiceSuccess(
          SemanticVoiceInterpretation(
            intent: SemanticVoiceIntent.addPurchase,
            merchantReference: 'Sharma',
            amountText: '300',
            item: 'paneer',
            rawTranscript: 'Sharma paneer 300',
          ),
        );
      };

      final transcript = VoiceTranscript(
        text: 'Sharma paneer 300',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      await controller.processTranscript(transcript);
      expect(controller.state.status, equals(VoiceStatus.ambiguousMerchant));

      // Merchant is deactivated before user selection
      await merchantRepository.deactivateMerchant('m_sharma_dairy');

      // User selects deactivated merchant
      await controller.selectCandidateMerchant(dairy);

      expect(controller.state.status, equals(VoiceStatus.error));
      expect(controller.state.errorMessage,
          contains('is no longer active'));
      expect(controller.state.command, isNull);
      expect(ledgerRepository.purchases, isEmpty);
    });

    // ========================================================================
    // 5. ERROR SANITIZATION & OFFLINE DEGRADATION
    // ========================================================================

    test(
        'Scenario 9: Network/Provider Exception -> Sanitized actionable error message, zero internal leak',
        () async {
      aiFallbackService.handler = (text) async {
        throw Exception('SocketException: Failed to connect to gemini.googleapis.com with api_key=AIzaSySecret');
      };

      final transcript = VoiceTranscript(
        text: 'Complex unstructured voice query',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      await controller.processTranscript(transcript);

      expect(controller.state.status, equals(VoiceStatus.error));
      expect(controller.state.errorMessage,
          equals("Couldn't understand that voice command. You can try again or enter it manually."));
      expect(controller.state.errorMessage, isNot(contains('gemini')));
      expect(controller.state.errorMessage, isNot(contains('api_key')));
      expect(controller.state.errorMessage, isNot(contains('SocketException')));
    });

    test('Scenario 10: Unresolved AI interpretation -> sanitized error', () async {
      aiFallbackService.handler = (text) async {
        return const SemanticVoiceUnresolved(
          rawTranscript: 'Random chatter',
          failureReason: 'AI model returned HTTP 500 internal error',
        );
      };

      final transcript = VoiceTranscript(
        text: 'Random chatter',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      await controller.processTranscript(transcript);

      expect(controller.state.status, equals(VoiceStatus.error));
      expect(controller.state.errorMessage,
          equals("Couldn't understand that voice command. You can try again or enter it manually."));
    });

    test('Scenario 11: Offline deterministic works without AI service', () async {
      // Controller without AI fallback service
      final offlineController = VoiceController(
        voiceService: voiceService,
        parser: const DeterministicVoiceCommandParser(),
        merchantRepository: merchantRepository,
        ledgerRepository: ledgerRepository,
        settlementRepository: settlementRepository,
        expenseRepository: expenseRepository,
        merchantResolver: const MerchantResolver(),
        aiFallbackService: null, // Offline
      );

      final transcript = VoiceTranscript(
        text: 'Sharma se doodh 150 ka liya',
        locale: 'en_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      await offlineController.processTranscript(transcript);

      expect(offlineController.state.status, equals(VoiceStatus.commandReady));
      expect(offlineController.state.understandingSource,
          equals(VoiceUnderstandingSource.deterministic));
      expect(offlineController.state.isAiAssisted, isFalse);

      final confirmed = await offlineController.executeConfirmedCommand();
      expect(confirmed, isTrue);
      expect(ledgerRepository.purchases.length, equals(1));
    });

    test('Scenario 12: Offline difficult command -> fails gracefully with actionable message', () async {
      final offlineController = VoiceController(
        voiceService: voiceService,
        parser: const DeterministicVoiceCommandParser(),
        merchantRepository: merchantRepository,
        ledgerRepository: ledgerRepository,
        settlementRepository: settlementRepository,
        expenseRepository: expenseRepository,
        merchantResolver: const MerchantResolver(),
        aiFallbackService: null, // Offline
      );

      final transcript = VoiceTranscript(
        text: 'Bhai Sharma ji ke yahan se kuch doodh laya tha',
        locale: 'hi_IN',
        isFinal: true,
        capturedAt: DateTime.now(),
      );

      await offlineController.processTranscript(transcript);

      expect(offlineController.state.status, equals(VoiceStatus.error));
      expect(offlineController.state.command, isNull);
      expect(offlineController.state.errorMessage, isNotNull);
      expect(offlineController.state.isAiAssisted, isFalse);
    });
  });
}

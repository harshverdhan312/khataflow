import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:khata_flow/features/voice/data/deterministic_voice_command_parser.dart';
import 'package:khata_flow/features/voice/domain/merchant_resolver.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_command_resolver.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_intent.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_interpretation.dart';
import 'package:khata_flow/features/voice/domain/voice_command.dart';
import 'package:khata_flow/features/voice/domain/voice_transcript.dart';
import 'package:khata_flow/features/voice/domain/voice_understanding_source.dart';
import 'package:khata_flow/features/voice/presentation/voice_confirmation_view.dart';
import 'package:khata_flow/features/voice/presentation/voice_controller.dart';
import 'package:khata_flow/features/voice/presentation/voice_entry_sheet.dart';
import 'package:khata_flow/features/voice/presentation/voice_providers.dart';
import 'package:khata_flow/features/voice/presentation/voice_state.dart';

// ============================================================================
// MOCKS
// ============================================================================

class FakeVoiceService implements VoiceService {
  @override
  Future<bool> initialize() async => true;
  @override
  bool get isAvailable => true;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> startListening({
    String? localeId,
    required void Function(String text, bool isFinal) onResult,
    required void Function(String error) onError,
  }) async {}
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> cancelListening() async {}
  @override
  bool get isListening => false;
}

class FakeMerchantRepository implements MerchantRepository {
  List<Merchant> merchants = [];

  @override
  Future<List<Merchant>> getActiveMerchants() async =>
      merchants.where((m) => m.isActive).toList();
  @override
  Future<Merchant?> getMerchantById(String id) async =>
      merchants.cast<Merchant?>().firstWhere((m) => m?.id == id, orElse: () => null);
  @override
  Future<Merchant> createMerchant(CreateMerchantInput input) async => throw UnimplementedError();
  @override
  Future<void> updateMerchant(Merchant merchant) async {}
  @override
  Future<void> deactivateMerchant(String id) async {}
  @override
  Future<void> reactivateMerchant(String id) async {}
  @override
  Stream<List<Merchant>> watchActiveMerchants() => Stream.value(merchants);
  @override
  Stream<List<Merchant>> watchInactiveMerchants() => Stream.value([]);
}

class FakeLedgerRepository implements LedgerRepository {
  @override
  Future<Purchase> addPurchase(CreatePurchaseInput input) async => throw UnimplementedError();
  @override
  Future<int> getOutstandingAmount(String merchantId) async => 0;
  @override
  Future<List<Purchase>> getUnsettledPurchases(String merchantId) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSettlementRepository implements SettlementRepository {
  @override
  Future<Settlement> recordSettlement({
    required String merchantId,
    required List<String> purchaseIds,
    String? paymentReference,
  }) async => throw UnimplementedError();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeExpenseRepository implements ExpenseRepository {
  @override
  Future<Expense> createExpense(CreateExpenseInput input) async => throw UnimplementedError();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('KhataFlow M8.6.5 — Voice AI Fallback UX Widget Tests', () {
    late FakeMerchantRepository merchantRepository;
    late FakeLedgerRepository ledgerRepository;
    late FakeSettlementRepository settlementRepository;
    late FakeExpenseRepository expenseRepository;
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
      merchantRepository = FakeMerchantRepository()..merchants = [testMerchant];
      ledgerRepository = FakeLedgerRepository();
      settlementRepository = FakeSettlementRepository();
      expenseRepository = FakeExpenseRepository();

      controller = VoiceController(
        voiceService: FakeVoiceService(),
        parser: const DeterministicVoiceCommandParser(),
        merchantRepository: merchantRepository,
        ledgerRepository: ledgerRepository,
        settlementRepository: settlementRepository,
        expenseRepository: expenseRepository,
        merchantResolver: const MerchantResolver(),
        semanticCommandResolver: const SemanticVoiceCommandResolver(),
      );
    });

    Widget createTestApp(Widget child) {
      return ProviderScope(
        overrides: [
          voiceControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: child,
          ),
        ),
      );
    }

    testWidgets(
        '1. VoiceStatus.aiFallback displays non-alarming loading UX with transcript and cancel button',
        (tester) async {
      await tester.pumpWidget(createTestApp(const VoiceEntrySheet()));
      await tester.pump();

      // Transition controller into aiFallback state
      controller.state = controller.state.copyWith(
        status: VoiceStatus.aiFallback,
        transcript: VoiceTranscript(
          text: 'Sharma ji se doodh liya tha',
          locale: 'hi_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );
      await tester.pump();

      // Verify UI text
      expect(find.text('Trying another way to understand that...'), findsOneWidget);
      expect(find.text('"Sharma ji se doodh liya tha"'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

      // Verify no internal technical terms are visible
      expect(find.textContaining('Gemini'), findsNothing);
      expect(find.textContaining('HTTP'), findsNothing);
      expect(find.textContaining('API'), findsNothing);
    });

    testWidgets(
        '2. Confirmation View displays subtle AI-assisted understanding badge when isAiAssisted is true',
        (tester) async {
      const command = AddPurchaseCommand(
        merchantName: 'Sharma General Store',
        items: [
          VoicePurchaseItem(name: 'Doodh', amountPaise: 25000),
        ],
        totalAmountPaise: 25000,
      );

      final state = VoiceState(
        status: VoiceStatus.commandReady,
        command: command,
        resolvedMerchant: testMerchant,
        understandingSource: VoiceUnderstandingSource.aiFallback,
      );

      expect(state.isAiAssisted, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceConfirmationView(
              voiceState: state,
              voiceController: controller,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('AI-assisted understanding'), findsOneWidget);
      expect(find.text('Review Purchase'), findsOneWidget);
      expect(find.text('Sharma General Store'), findsOneWidget);
      expect(find.text('Doodh'), findsOneWidget);
      expect(find.text('₹250'), findsNWidgets(2)); // item + total
    });

    testWidgets(
        '3. Confirmation View does NOT display AI-assisted badge for deterministic commands',
        (tester) async {
      const command = AddPurchaseCommand(
        merchantName: 'Sharma General Store',
        items: [
          VoicePurchaseItem(name: 'Doodh', amountPaise: 25000),
        ],
        totalAmountPaise: 25000,
      );

      final state = VoiceState(
        status: VoiceStatus.commandReady,
        command: command,
        resolvedMerchant: testMerchant,
        understandingSource: VoiceUnderstandingSource.deterministic,
      );

      expect(state.isAiAssisted, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceConfirmationView(
              voiceState: state,
              voiceController: controller,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('AI-assisted understanding'), findsNothing);
      expect(find.text('Review Purchase'), findsOneWidget);
    });

    testWidgets(
        '4. Error view displays actionable guidance and provides Enter Manually & Try Again actions',
        (tester) async {
      await tester.pumpWidget(createTestApp(const VoiceEntrySheet()));
      await tester.pump();

      controller.state = controller.state.copyWith(
        status: VoiceStatus.error,
        errorMessage: "Couldn't understand that voice command. You can try again or enter it manually.",
      );
      await tester.pump();

      expect(find.text('Could not process voice entry'), findsOneWidget);
      expect(
          find.text("Couldn't understand that voice command. You can try again or enter it manually."),
          findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Enter Manually'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Try Again'), findsOneWidget);
    });

    testWidgets('5. Ambiguous merchant picker renders candidates cleanly', (tester) async {
      final dairy = Merchant(
        id: 'm_sharma_dairy',
        name: 'Sharma Dairy',
        category: MerchantCategory.milk,
        upiVpa: '',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final state = VoiceState(
        status: VoiceStatus.ambiguousMerchant,
        candidateMerchants: [testMerchant, dairy],
        pendingInterpretation: const SemanticVoiceInterpretation(
          intent: SemanticVoiceIntent.addPurchase,
          merchantReference: 'Sharma',
          amountText: '250',
          item: 'doodh',
          rawTranscript: 'Sharma doodh 250',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceConfirmationView(
              voiceState: state,
              voiceController: controller,
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Which store did you mean?'), findsOneWidget);
      expect(find.text('Sharma General Store'), findsOneWidget);
      expect(find.text('Sharma Dairy'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
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
import 'package:khata_flow/features/voice/presentation/voice_confirmation_view.dart';
import 'package:khata_flow/features/voice/presentation/voice_controller.dart';
import 'package:khata_flow/features/voice/presentation/voice_state.dart';

class StubVoiceService implements VoiceService {
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

class StubMerchantRepository implements MerchantRepository {
  List<Merchant> merchants = [];
  @override
  Future<List<Merchant>> getActiveMerchants() async => merchants;
  @override
  Future<Merchant?> getMerchantById(String id) async => null;
  @override
  Future<Merchant> createMerchant(CreateMerchantInput input) async => throw UnimplementedError();
  @override
  Future<void> deactivateMerchant(String merchantId) async {}
  @override
  Future<void> reactivateMerchant(String merchantId) async {}
  @override
  Future<void> updateMerchant(Merchant merchant) async {}
  @override
  Stream<List<Merchant>> watchActiveMerchants() => Stream.value(merchants);
  @override
  Stream<List<Merchant>> watchInactiveMerchants() => Stream.value([]);
}

class StubLedgerRepository implements LedgerRepository {
  List<Purchase> recordedPurchases = [];
  @override
  Future<Purchase> addPurchase(CreatePurchaseInput input) async {
    final purchase = Purchase(
      id: 'p1',
      merchantId: input.merchantId,
      amountPaise: input.amountPaise,
      note: input.note,
      category: input.category,
      purchaseDate: input.purchaseDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    recordedPurchases.add(purchase);
    return purchase;
  }
  @override
  Future<List<Purchase>> getPurchases(String merchantId) async => [];
  @override
  Future<List<Purchase>> getUnsettledPurchases(String merchantId) async => [
    Purchase(
      id: 'p_unsettled',
      merchantId: merchantId,
      amountPaise: 50000,
      note: 'Milk',
      purchaseDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    )
  ];
  @override
  Future<int> getOutstandingAmount(String merchantId) async => 0;
  @override
  Future<int> getTotalOutstanding() async => 0;
  @override
  Stream<int> watchOutstandingAmount(String merchantId) => Stream.value(0);
  @override
  Stream<List<Purchase>> watchPurchases(String merchantId) => Stream.value([]);
  @override
  Stream<int> watchTotalOutstanding() => Stream.value(0);
}

class StubSettlementRepository implements SettlementRepository {
  int recordSettlementCalls = 0;
  @override
  Future<Settlement> recordSettlement({required String merchantId, required List<String> purchaseIds, String? paymentReference}) async {
    recordSettlementCalls++;
    return Settlement(
      id: 's1',
      merchantId: merchantId,
      amountPaise: 50000,
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
  Future<Settlement> initiateSettlement({required String merchantId, required List<String> purchaseIds}) async => throw UnimplementedError();
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

void main() {
  group('VoiceConfirmationView Widget Tests', () {
    late StubMerchantRepository merchantRepo;
    late StubLedgerRepository ledgerRepo;
    late StubSettlementRepository settlementRepo;
    late VoiceController controller;

    final testMerchant = Merchant(
      id: 'm1',
      name: 'Sharma General Store',
      category: MerchantCategory.grocery,
      phone: '9876543210',
      upiVpa: 'sharma@upi',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final secondMerchant = Merchant(
      id: 'm2',
      name: 'Sharma Sweets',
      category: MerchantCategory.other,
      phone: '9876543211',
      upiVpa: 'sharmasweets@upi',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      merchantRepo = StubMerchantRepository();
      ledgerRepo = StubLedgerRepository();
      settlementRepo = StubSettlementRepository();
      merchantRepo.merchants = [testMerchant, secondMerchant];

      controller = VoiceController(
        voiceService: StubVoiceService(),
        parser: const DeterministicVoiceCommandParser(),
        merchantRepository: merchantRepo,
        ledgerRepository: ledgerRepo,
        settlementRepository: settlementRepo,
        merchantResolver: const MerchantResolver(),
      );
    });

    testWidgets('Displays purchase confirmation with items, total, and disclaimer', (tester) async {
      bool dismissed = false;

      final state = VoiceState(
        status: VoiceStatus.commandReady,
        resolvedMerchant: testMerchant,
        command: const AddPurchaseCommand(
          merchantName: 'Sharma',
          items: [
            VoicePurchaseItem(name: 'Milk', amountPaise: 6000),
            VoicePurchaseItem(name: 'Bread', amountPaise: 4000),
          ],
          totalAmountPaise: 10000,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceConfirmationView(
              voiceState: state,
              voiceController: controller,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('Review Purchase'), findsOneWidget);
      expect(find.text('Sharma General Store'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('₹60'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
      expect(find.text('₹40'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('₹100'), findsOneWidget);
      expect(find.text('Tapping confirm will record this entry in your local ledger.'), findsOneWidget);
      expect(find.text('Record Purchase'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Cancel tap
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
      expect(ledgerRepo.recordedPurchases, isEmpty);
    });

    testWidgets('Displays settlement confirmation with amount and disclaimer', (tester) async {
      final state = VoiceState(
        status: VoiceStatus.commandReady,
        resolvedMerchant: testMerchant,
        command: const RecordSettlementCommand(
          merchantName: 'Sharma',
          amountPaise: 50000,
          paymentReference: 'UPI-REF-1234',
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

      expect(find.text('Review Settlement'), findsOneWidget);
      expect(find.text('Sharma General Store'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);
      expect(find.text('Payment Reference'), findsOneWidget);
      expect(find.text('UPI-REF-1234'), findsOneWidget);
      expect(find.text('Record Settlement'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Displays ambiguous merchant picker when multiple stores match', (tester) async {
      final state = VoiceState(
        status: VoiceStatus.ambiguousMerchant,
        candidateMerchants: [testMerchant, secondMerchant],
        command: const AddPurchaseCommand(
          merchantName: 'Sharma',
          items: [VoicePurchaseItem(name: 'Milk', amountPaise: 6000)],
          totalAmountPaise: 6000,
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

      expect(find.text('Which store did you mean?'), findsOneWidget);
      expect(find.text('Sharma General Store'), findsOneWidget);
      expect(find.text('Sharma Sweets'), findsOneWidget);
    });

    testWidgets('Displays full settlement confirmation with live outstanding balance and optional payment reference', (tester) async {
      final state = VoiceState(
        status: VoiceStatus.commandReady,
        resolvedMerchant: testMerchant,
        outstandingPaiseToSettle: 85000,
        command: const SettleMerchantCommand(
          merchantName: 'Sharma',
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

      expect(find.text('Settle Store Ledger'), findsOneWidget);
      expect(find.text('Sharma General Store'), findsOneWidget);
      expect(find.text('Outstanding Balance'), findsOneWidget);
      expect(find.text('₹850'), findsOneWidget);
      expect(find.text('Payment Reference (Optional)'), findsOneWidget);
      expect(find.text('Settle ₹850'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Displays full settlement with zero balance shows Close button only', (tester) async {
      final state = VoiceState(
        status: VoiceStatus.commandReady,
        resolvedMerchant: testMerchant,
        outstandingPaiseToSettle: 0,
        command: const SettleMerchantCommand(
          merchantName: 'Sharma',
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

      expect(find.text('Settle Store Ledger'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);
      expect(find.text('There are no unsettled purchases for this store.'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Record Settlement'), findsNothing);
    });

    testWidgets('Displays create merchant confirmation with category chips and optional UPI VPA', (tester) async {
      final state = VoiceState(
        status: VoiceStatus.commandReady,
        pendingCategory: MerchantCategory.grocery,
        pendingUpiVpa: 'rahul@oksbi',
        command: const CreateMerchantCommand(
          merchantName: 'Rahul Sabji Wale',
          category: MerchantCategory.grocery,
          upiVpa: 'rahul@oksbi',
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

      expect(find.text('Create Store Ledger'), findsOneWidget);
      expect(find.text('Rahul Sabji Wale'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Grocery'), findsOneWidget);
      expect(find.text('Milk & Dairy'), findsOneWidget);
      expect(find.text('Laundry'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('UPI ID / VPA (Optional)'), findsOneWidget);
      expect(find.text('Create Ledger'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}

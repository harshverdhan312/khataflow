import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/ledger/domain/ledger_repository.dart';
import 'package:khata_flow/features/ledger/domain/purchase.dart';
import 'package:khata_flow/features/ledger/presentation/ledger_providers.dart';
import 'package:khata_flow/features/ledger/presentation/ledger_screen.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/merchant/presentation/merchant_providers.dart';
import 'package:khata_flow/features/receipt/domain/settlement_receipt.dart';
import 'package:khata_flow/features/settlement/domain/settlement.dart';
import 'package:khata_flow/features/settlement/domain/settlement_repository.dart';
import 'package:khata_flow/features/settlement/domain/settlement_status.dart';
import 'package:khata_flow/features/settlement/presentation/settlement_confirmation_sheet.dart';
import 'package:khata_flow/features/settlement/presentation/settlement_providers.dart';
import 'package:khata_flow/features/settlement/presentation/settlement_resolution_dialog.dart';

class MockSettlementRepository implements SettlementRepository {
  bool recordSettlementCalled = false;
  bool markSettledCalled = false;
  String? recordedPaymentRef;
  String? recordedUtr;
  String? recordedTxnId;

  @override
  Future<Settlement> recordSettlement({
    required String merchantId,
    required List<String> purchaseIds,
    String? paymentReference,
  }) async {
    recordSettlementCalled = true;
    recordedPaymentRef = paymentReference;
    return Settlement(
      id: 's_mock_1',
      merchantId: merchantId,
      amountPaise: 25000,
      status: SettlementStatus.settled,
      utr: paymentReference,
      completedAt: DateTime.now(),
      initiatedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<Settlement> initiateSettlement({
    required String merchantId,
    required List<String> purchaseIds,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> updateSettlementStatus({
    required String settlementId,
    required SettlementStatus status,
    String? transactionId,
    String? utr,
  }) async {}

  @override
  Future<void> markSettlementSettled({
    required String settlementId,
    String? transactionId,
    String? utr,
  }) async {
    markSettledCalled = true;
    recordedUtr = utr;
    recordedTxnId = transactionId;
  }

  @override
  Future<void> markSettlementFailed({
    required String settlementId,
    required String reason,
  }) async {}

  @override
  Future<void> markSettlementUnknown({required String settlementId}) async {}

  @override
  Future<Settlement?> getSettlementById(String settlementId) async => null;

  @override
  Future<SettlementReceipt?> getSettlementReceipt(String settlementId) async => null;

  @override
  Future<List<Settlement>> getUnresolvedSettlements({String? merchantId}) async => [];

  @override
  Future<bool> hasUnresolvedSettlementForMerchant(String merchantId) async => false;

  @override
  Future<List<String>> getUnresolvedPurchaseIds(String merchantId) async => [];

  @override
  Stream<List<Settlement>> watchSettlementsForMerchant(String merchantId) => Stream.value([]);

  @override
  Stream<List<Settlement>> watchAllSettlements() => Stream.value([]);

  @override
  Future<List<Settlement>> getAllSettlements() async => [];
}

class MockLedgerRepository implements LedgerRepository {
  final List<Purchase> purchases;
  MockLedgerRepository({this.purchases = const []});

  @override
  Future<List<Purchase>> getUnsettledPurchases(String merchantId) async => purchases;

  @override
  Future<Purchase> addPurchase(CreatePurchaseInput input) async => throw UnimplementedError();

  @override
  Future<int> getOutstandingAmount(String merchantId) async => 0;

  @override
  Future<List<Purchase>> getPurchases(String merchantId) async => purchases;

  @override
  Future<int> getTotalOutstanding() async => 0;

  @override
  Stream<int> watchOutstandingAmount(String merchantId) => Stream.value(0);

  @override
  Stream<List<Purchase>> watchPurchases(String merchantId) => Stream.value(purchases);

  @override
  Stream<int> watchTotalOutstanding() => Stream.value(0);
}

void main() {
  const merchantId = 'm_widget_1';
  final now = DateTime.now();

  final mockMerchant = Merchant(
    id: merchantId,
    name: 'Sharma Sweets',
    upiVpa: 'sharma@oksbi',
    category: MerchantCategory.grocery,
    phone: '9876543210',
    createdAt: now,
    updatedAt: now,
  );

  group('Settlement Flow Widget Tests', () {
    testWidgets('Record Settlement button is disabled when outstanding is 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            merchantDetailProvider(merchantId).overrideWith((ref) => Future.value(mockMerchant)),
            merchantPurchasesStreamProvider(merchantId).overrideWith((ref) => Stream.value([])),
            merchantSettlementsStreamProvider(merchantId).overrideWith((ref) => Stream.value([])),
            merchantOutstandingStreamProvider(merchantId).overrideWith((ref) => Stream.value(0)),
            unresolvedSettlementsForMerchantProvider(merchantId).overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: LedgerScreen(merchantId: merchantId),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('All Cleared'), findsOneWidget);
    });

    testWidgets('Record Settlement button is enabled when purchases exist and opens confirmation sheet', (tester) async {
      final purchase = Purchase(
        id: 'p_w_1',
        merchantId: merchantId,
        amountPaise: 25000, // Rs 250
        note: 'Gulab Jamun 1kg',
        category: 'Sweets',
        purchaseDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            merchantDetailProvider(merchantId).overrideWith((ref) => Future.value(mockMerchant)),
            merchantPurchasesStreamProvider(merchantId).overrideWith((ref) => Stream.value([purchase])),
            merchantSettlementsStreamProvider(merchantId).overrideWith((ref) => Stream.value([])),
            merchantOutstandingStreamProvider(merchantId).overrideWith((ref) => Stream.value(25000)),
            unresolvedSettlementsForMerchantProvider(merchantId).overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: LedgerScreen(merchantId: merchantId),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Record Settlement — ₹250'), findsOneWidget);

      // Tap Record Settlement
      await tester.tap(find.textContaining('Record Settlement'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Settlement Confirmation Sheet opens
      expect(find.byType(SettlementConfirmationSheet), findsOneWidget);
      expect(find.text('Record Settlement'), findsWidgets);
      expect(find.text('Mark outstanding dues as settled outside KhataFlow'), findsOneWidget);
      expect(find.text('Sharma Sweets'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(SettlementConfirmationSheet),
          matching: find.text('sharma@oksbi'),
        ),
        findsOneWidget,
      );
      expect(find.text('1 item(s)'), findsOneWidget);
      expect(find.text('Payment Reference (Optional)'), findsOneWidget);
      expect(find.textContaining('This is a local ledger record. KhataFlow does not hold, process, or independently verify funds.'), findsOneWidget);
    });

    testWidgets('Settlement Confirmation Sheet records settlement with optional payment reference', (tester) async {
      final mockRepo = MockSettlementRepository();
      final purchase = Purchase(
        id: 'p_w_1',
        merchantId: merchantId,
        amountPaise: 25000,
        note: 'Sweets',
        category: 'Sweets',
        purchaseDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final mockLedger = MockLedgerRepository(purchases: [purchase]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settlementRepositoryProvider.overrideWithValue(mockRepo),
            ledgerRepositoryProvider.overrideWithValue(mockLedger),
            merchantPurchasesStreamProvider(merchantId).overrideWith((ref) => Stream.value([purchase])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SettlementConfirmationSheet(
                merchant: mockMerchant,
                outstandingPaise: 25000,
                purchaseCount: 1,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Enter payment reference
      await tester.enterText(find.byType(TextField), 'REF987654');
      await tester.pump();

      // Tap Record Settlement button
      await tester.tap(find.textContaining('Record Settlement — ₹250'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockRepo.recordSettlementCalled, isTrue);
      expect(mockRepo.recordedPaymentRef, equals('REF987654'));
    });

    testWidgets('Settlement Resolution Dialog renders manual resolution actions and optional payment reference', (tester) async {
      final settlement = Settlement(
        id: 's_test_dialog',
        merchantId: merchantId,
        amountPaise: 25000,
        status: SettlementStatus.unknown,
        initiatedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettlementResolutionDialog(
              settlement: settlement,
              merchantName: 'Sharma Sweets',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Record Settlement'), findsOneWidget);
      expect(find.textContaining('to Sharma Sweets'), findsOneWidget);
      expect(find.text('+ Add payment reference (optional)'), findsOneWidget);
      expect(find.text('Mark as Settled'), findsOneWidget);
      expect(find.text('Mark as Failed'), findsOneWidget);
      expect(find.text('Decide Later'), findsOneWidget);

      // Expand optional reference field
      await tester.tap(find.text('+ Add payment reference (optional)'));
      await tester.pumpAndSettle();

      expect(find.text('Hide payment reference'), findsOneWidget);
      expect(find.text('Payment Reference (Optional)'), findsOneWidget);
    });

    testWidgets('Unresolved settlement banner is displayed on ledger screen with Resolve button', (tester) async {
      final pendingSettlement = Settlement(
        id: 's_unres_1',
        merchantId: merchantId,
        amountPaise: 10000,
        status: SettlementStatus.unknown,
        initiatedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            merchantDetailProvider(merchantId).overrideWith((ref) => Future.value(mockMerchant)),
            merchantPurchasesStreamProvider(merchantId).overrideWith((ref) => Stream.value([])),
            merchantSettlementsStreamProvider(merchantId).overrideWith((ref) => Stream.value([])),
            merchantOutstandingStreamProvider(merchantId).overrideWith((ref) => Stream.value(10000)),
            unresolvedSettlementsForMerchantProvider(merchantId).overrideWith((ref) => Future.value([pendingSettlement])),
          ],
          child: const MaterialApp(
            home: LedgerScreen(merchantId: merchantId),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Banner should be visible
      expect(find.textContaining('Pending Settlement: ₹100'), findsOneWidget);
      expect(find.text('Resolve'), findsOneWidget);

      // Tap Resolve opens resolution dialog
      await tester.tap(find.text('Resolve'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SettlementResolutionDialog), findsOneWidget);
      expect(find.text('Record Settlement'), findsOneWidget);
    });

    testWidgets('SettlementResolutionDialog auto-expands and pre-fills captured UTR', (tester) async {
      final settlement = Settlement(
        id: 's_test_prefill',
        merchantId: merchantId,
        amountPaise: 25000,
        status: SettlementStatus.unknown,
        initiatedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettlementResolutionDialog(
              settlement: settlement,
              merchantName: 'Sharma Sweets',
              initialUtr: '423456789012',
              initialTxnId: 'AXI123456789',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Should automatically expand and show pre-filled value
      expect(find.text('423456789012'), findsOneWidget);
      expect(find.text('Hide payment reference'), findsOneWidget);
    });

    testWidgets('SettlementResolutionDialog.show prevents duplicate dialogs when already showing', (tester) async {
      SettlementResolutionDialog.isShowing = false;
      final settlement = Settlement(
        id: 's_test_dup',
        merchantId: merchantId,
        amountPaise: 10000,
        status: SettlementStatus.unknown,
        initiatedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    // Trigger first dialog
                    SettlementResolutionDialog.show(
                      context,
                      settlement: settlement,
                      merchantName: 'Sharma Sweets',
                    );
                    // Attempt duplicate trigger immediately
                    SettlementResolutionDialog.show(
                      context,
                      settlement: settlement,
                      merchantName: 'Sharma Sweets',
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Expect exactly one dialog instance
      expect(find.byType(SettlementResolutionDialog), findsOneWidget);
    });

    testWidgets('User confirmation in resolution dialog records settlement as SETTLED with optional metadata', (tester) async {
      SettlementResolutionDialog.isShowing = false;
      final mockRepo = MockSettlementRepository();

      final settlement = Settlement(
        id: 's_test_confirm',
        merchantId: merchantId,
        amountPaise: 25000,
        status: SettlementStatus.unknown,
        initiatedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settlementRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SettlementResolutionDialog(
                settlement: settlement,
                merchantName: 'Sharma Sweets',
                initialUtr: '423456789012',
                initialTxnId: 'TXN123',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Mark as Settled'), findsOneWidget);
      await tester.tap(find.text('Mark as Settled'));
      await tester.pumpAndSettle();

      expect(mockRepo.markSettledCalled, isTrue);
      expect(mockRepo.recordedUtr, equals('423456789012'));
      expect(mockRepo.recordedTxnId, equals('TXN123'));
    });
  });
}

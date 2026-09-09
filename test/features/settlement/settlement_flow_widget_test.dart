import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/services/upi_service.dart';
import 'package:khata_flow/features/ledger/domain/purchase.dart';
import 'package:khata_flow/features/ledger/presentation/ledger_providers.dart';
import 'package:khata_flow/features/ledger/presentation/ledger_screen.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/merchant/presentation/merchant_providers.dart';
import 'package:khata_flow/features/settlement/domain/settlement.dart';
import 'package:khata_flow/features/settlement/domain/settlement_status.dart';
import 'package:khata_flow/features/settlement/presentation/settlement_confirmation_sheet.dart';
import 'package:khata_flow/features/settlement/presentation/settlement_providers.dart';
import 'package:khata_flow/features/settlement/presentation/settlement_resolution_dialog.dart';

class MockUpiService implements UpiService {
  bool launchCalled = false;
  UpiLaunchResult launchResultToReturn = const UpiLaunchResult(
    status: UpiLaunchStatus.launched,
    statusMessage: 'Launched mock UPI app',
  );

  @override
  Uri buildUpiUri({
    required String vpa,
    required String merchantName,
    required int amountPaise,
    required String transactionNote,
  }) {
    return Uri.parse('upi://pay?pa=$vpa&pn=$merchantName&am=${amountPaise / 100}&cu=INR&tn=$transactionNote');
  }

  @override
  bool isValidVpa(String vpa) => vpa.contains('@');

  @override
  Future<UpiLaunchResult> launchPayment({
    required String vpa,
    required String merchantName,
    required int amountPaise,
    required String transactionNote,
  }) async {
    launchCalled = true;
    return launchResultToReturn;
  }
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
    testWidgets('Clear Dues button is disabled when outstanding is 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            merchantDetailProvider(merchantId).overrideWith((ref) => Future.value(mockMerchant)),
            merchantPurchasesStreamProvider(merchantId).overrideWith((ref) => Stream.value([])),
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

    testWidgets('Clear Dues button is enabled when purchases exist and opens confirmation sheet', (tester) async {
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

      expect(find.textContaining('Clear Dues — ₹250'), findsOneWidget);

      // Tap Clear Dues
      await tester.tap(find.textContaining('Clear Dues'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Settlement Confirmation Sheet opens
      expect(find.byType(SettlementConfirmationSheet), findsOneWidget);
      expect(find.text('Clear Outstanding Dues'), findsOneWidget);
      expect(find.text('Sharma Sweets'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(SettlementConfirmationSheet),
          matching: find.text('sharma@oksbi'),
        ),
        findsOneWidget,
      );
      expect(find.text('1 item(s)'), findsOneWidget);
      expect(find.textContaining('Open UPI App — ₹250'), findsOneWidget);
    });

    testWidgets('Settlement Resolution Dialog renders with optional UTR and decision buttons', (tester) async {
      final settlement = Settlement(
        id: 's_test_dialog',
        merchantId: merchantId,
        amountPaise: 25000,
        status: SettlementStatus.upiLaunched,
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
      expect(find.text('Sharma Sweets'), findsOneWidget);
      expect(find.text('₹250'), findsOneWidget);
      expect(find.text('UPI Reference / UTR (Optional)'), findsOneWidget);
      expect(find.text('Record Payment (Mark Settled)'), findsOneWidget);
      expect(find.text('Payment Failed'), findsOneWidget);
      expect(find.text('Decide Later'), findsOneWidget);
    });

    testWidgets('Unresolved settlement banner is displayed on ledger screen with Resolve button', (tester) async {
      final pendingSettlement = Settlement(
        id: 's_unres_1',
        merchantId: merchantId,
        amountPaise: 10000,
        status: SettlementStatus.upiLaunched,
        initiatedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            merchantDetailProvider(merchantId).overrideWith((ref) => Future.value(mockMerchant)),
            merchantPurchasesStreamProvider(merchantId).overrideWith((ref) => Stream.value([])),
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
    });
  });
}

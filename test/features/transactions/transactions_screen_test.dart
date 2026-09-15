import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/settlement/domain/settlement.dart';
import 'package:khata_flow/features/settlement/domain/settlement_item.dart';
import 'package:khata_flow/features/settlement/domain/settlement_status.dart';
import 'package:khata_flow/features/transactions/presentation/transaction_detail_sheet.dart';
import 'package:khata_flow/features/transactions/presentation/transactions_providers.dart';
import 'package:khata_flow/features/transactions/presentation/transactions_screen.dart';

void main() {
  final now = DateTime.now();

  final mockMerchant1 = Merchant(
    id: 'm_tx_1',
    name: 'Gupta Grocery',
    upiVpa: 'gupta@okaxis',
    category: MerchantCategory.grocery,
    createdAt: now,
    updatedAt: now,
  );

  final mockMerchant2 = Merchant(
    id: 'm_tx_2',
    name: 'Sharma Sweets',
    upiVpa: 'sharma@oksbi',
    category: MerchantCategory.grocery,
    createdAt: now,
    updatedAt: now,
  );

  group('TransactionsScreen & TransactionDetailSheet Widget Tests', () {
    testWidgets('renders empty state when there are no transactions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTransactionsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('No Transactions Yet'), findsOneWidget);
      expect(
        find.text('Payments and settlements you clear will be recorded here.'),
        findsOneWidget,
      );
    });

    testWidgets('renders list of transactions with correct status badges and metadata', (tester) async {
      final settledTx = Settlement(
        id: 's_settled',
        merchantId: 'm_tx_1',
        amountPaise: 45000, // Rs 450
        status: SettlementStatus.settled,
        utr: '423456789012',
        transactionId: 'TXN_450',
        initiatedAt: now.subtract(const Duration(hours: 2)),
        completedAt: now.subtract(const Duration(hours: 1)),
        createdAt: now,
        updatedAt: now,
        items: [
          SettlementItem(settlementId: 's_settled', purchaseId: 'p1', amountPaise: 45000),
        ],
      );

      final failedTx = Settlement(
        id: 's_failed',
        merchantId: 'm_tx_2',
        amountPaise: 12000, // Rs 120
        status: SettlementStatus.failed,
        initiatedAt: now.subtract(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );

      final pendingTx = Settlement(
        id: 's_unknown',
        merchantId: 'm_tx_1',
        amountPaise: 8000, // Rs 80
        status: SettlementStatus.unknown,
        initiatedAt: now.subtract(const Duration(minutes: 30)),
        createdAt: now,
        updatedAt: now,
      );

      final enrichedList = [
        EnrichedSettlement(settlement: settledTx, merchant: mockMerchant1),
        EnrichedSettlement(settlement: failedTx, merchant: mockMerchant2),
        EnrichedSettlement(settlement: pendingTx, merchant: mockMerchant1),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTransactionsStreamProvider.overrideWith((ref) => Stream.value(enrichedList)),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Check merchant names
      expect(find.text('Gupta Grocery'), findsNWidgets(2));
      expect(find.text('Sharma Sweets'), findsOneWidget);

      // Check amounts
      expect(find.text('₹450'), findsOneWidget);
      expect(find.text('₹120'), findsOneWidget);
      expect(find.text('₹80'), findsOneWidget);

      // Check status labels
      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);

      // Check Ref indicator
      expect(find.text('Ref: 423456789012'), findsOneWidget);
    });

    testWidgets('tapping a transaction card opens TransactionDetailSheet with full details', (tester) async {
      final settledTx = Settlement(
        id: 's_settled_detail',
        merchantId: 'm_tx_1',
        amountPaise: 35000, // Rs 350
        status: SettlementStatus.settled,
        utr: '987654321012',
        transactionId: 'TXN_TEST_350',
        initiatedAt: now.subtract(const Duration(hours: 3)),
        completedAt: now.subtract(const Duration(hours: 2)),
        createdAt: now,
        updatedAt: now,
        items: [
          SettlementItem(settlementId: 's_settled_detail', purchaseId: 'p1', amountPaise: 20000),
          SettlementItem(settlementId: 's_settled_detail', purchaseId: 'p2', amountPaise: 15000),
        ],
      );

      final enrichedList = [
        EnrichedSettlement(settlement: settledTx, merchant: mockMerchant1),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTransactionsStreamProvider.overrideWith((ref) => Stream.value(enrichedList)),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Tap the transaction card
      await tester.tap(find.text('Gupta Grocery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify sheet is displayed
      expect(find.byType(TransactionDetailSheet), findsOneWidget);
      expect(find.text('₹350'), findsWidgets);
      expect(find.text('987654321012'), findsOneWidget);
      expect(find.text('TXN_TEST_350'), findsOneWidget);
      expect(find.text('2 purchases included'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('unresolved transaction detail sheet shows Resolve Payment Status action button', (tester) async {
      final unresolvedTx = Settlement(
        id: 's_unresolved_sheet',
        merchantId: 'm_tx_1',
        amountPaise: 20000, // Rs 200
        status: SettlementStatus.unknown,
        initiatedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TransactionDetailSheet(
                settlement: unresolvedTx,
                merchant: mockMerchant1,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Resolve Payment Status'), findsOneWidget);
      expect(find.text('Pending Confirmation'), findsOneWidget);
      expect(find.text('View Receipt'), findsNothing);
    });

    testWidgets('settled transaction detail sheet shows View Receipt button', (tester) async {
      final settledTx = Settlement(
        id: 's_settled_receipt_btn',
        merchantId: 'm_tx_1',
        amountPaise: 25000,
        status: SettlementStatus.settled,
        initiatedAt: now,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TransactionDetailSheet(
                settlement: settledTx,
                merchant: mockMerchant1,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('View Receipt'), findsOneWidget);
      expect(find.text('Resolve Payment Status'), findsNothing);
    });
  });
}


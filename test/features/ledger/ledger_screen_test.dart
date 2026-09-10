import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/ledger/domain/purchase.dart';
import 'package:khata_flow/features/ledger/presentation/ledger_providers.dart';
import 'package:khata_flow/features/ledger/presentation/ledger_screen.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/merchant/presentation/merchant_providers.dart';
import 'package:khata_flow/features/settlement/presentation/settlement_providers.dart';


import 'package:khata_flow/features/settlement/domain/settlement.dart';
import 'package:khata_flow/features/settlement/domain/settlement_status.dart';

void main() {
  testWidgets('Ledger screen displays header, tabs, purchases, and settlements correctly', (tester) async {
    final now = DateTime.now();
    final merchant = Merchant(
      id: 'm1',
      name: 'Sharma Kirana',
      category: MerchantCategory.grocery,
      upiVpa: 'sharma@upi',
      phone: '9876543210',
      createdAt: now,
      updatedAt: now,
    );

    final purchase = Purchase(
      id: 'p1',
      merchantId: 'm1',
      amountPaise: 45000,
      note: 'Vegetables',
      category: 'Daily',
      purchaseDate: now,
      createdAt: now,
      updatedAt: now,
      isSettled: false,
    );

    final settlement = Settlement(
      id: 's1',
      merchantId: 'm1',
      amountPaise: 45000,
      status: SettlementStatus.settled,
      utr: '423456789012',
      initiatedAt: now,
      completedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantDetailProvider('m1').overrideWith(
            (ref) => Future.value(merchant),
          ),
          merchantPurchasesStreamProvider('m1').overrideWith(
            (ref) => Stream.value([purchase]),
          ),
          merchantSettlementsStreamProvider('m1').overrideWith(
            (ref) => Stream.value([settlement]),
          ),
          merchantOutstandingStreamProvider('m1').overrideWith(
            (ref) => Stream.value(45000),
          ),
          unresolvedSettlementsForMerchantProvider('m1').overrideWith(
            (ref) => Future.value([]),
          ),
        ],
        child: const MaterialApp(
          home: LedgerScreen(merchantId: 'm1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    // Verify header
    expect(find.text('Sharma Kirana'), findsWidgets);
    expect(find.text('sharma@upi'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('CURRENT OUTSTANDING'), findsOneWidget);
    expect(find.text('Grocery'), findsOneWidget);

    // Verify Tabs
    expect(find.text('Purchases (1)'), findsOneWidget);
    expect(find.text('Settlements (1)'), findsOneWidget);

    // Verify purchase
    expect(find.text('Vegetables'), findsOneWidget);
    expect(find.text('₹450'), findsWidgets);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);

    // Switch to Settlements tab
    await tester.tap(find.text('Settlements (1)'));
    await tester.pumpAndSettle();

    // Verify Settlement Item
    expect(find.text('SETTLED'), findsOneWidget);
    expect(find.text('UTR: 423456789012'), findsOneWidget);
  });
}

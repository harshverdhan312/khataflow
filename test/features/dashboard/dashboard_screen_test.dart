import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:khata_flow/features/dashboard/presentation/dashboard_providers.dart';
import 'package:khata_flow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';

void main() {
  testWidgets('Dashboard displays empty state when no merchants exist', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardSummaryStreamProvider.overrideWith(
            (ref) => Stream.value(
              const DashboardSummary(
                totalOutstandingPaise: 0,
                merchantSummaries: [],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No store tabs yet'), findsOneWidget);
    expect(find.text('Add Your First Store'), findsOneWidget);
  });

  testWidgets('Dashboard displays active merchants and outstanding total', (tester) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardSummaryStreamProvider.overrideWith(
            (ref) => Stream.value(
              DashboardSummary(
                totalOutstandingPaise: 77000,
                merchantSummaries: [
                  MerchantLedgerSummary(
                    merchant: Merchant(
                      id: 'm1',
                      name: 'Sharma Kirana',
                      category: MerchantCategory.grocery,
                      upiVpa: 'sharma@upi',
                      createdAt: now,
                      updatedAt: now,
                    ),
                    outstandingPaise: 77000,
                    lastActiveAt: now,
                  ),
                ],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('TOTAL OUTSTANDING DUES'), findsOneWidget);
    expect(find.text('₹770'), findsWidgets);
    expect(find.text('Sharma Kirana'), findsOneWidget);
    expect(find.text('Grocery'), findsOneWidget);
    expect(find.text('sharma@upi'), findsOneWidget);
  });
}

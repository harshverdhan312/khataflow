import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khata_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:khata_flow/features/dashboard/presentation/dashboard_providers.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/merchant/presentation/merchant_providers.dart';
import 'package:khata_flow/features/navigation/presentation/main_nav_screen.dart';
import 'package:khata_flow/features/transactions/presentation/transactions_providers.dart';

void main() {
  group('MainNavScreen Bottom Navigation Tests', () {
    testWidgets('renders Home, Expenses, and Transactions tabs and switches IndexedStack', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const MainNavScreen(),
          ),
        ],
      );

      final app = ProviderScope(
        overrides: [
          dashboardSummaryStreamProvider.overrideWith((ref) => Stream.value(
                const DashboardSummary(
                  totalOutstandingPaise: 0,
                  merchantSummaries: [],
                ),
              )),
          inactiveMerchantsStreamProvider.overrideWith((ref) => Stream.value([])),
          allTransactionsStreamProvider.overrideWith((ref) => Stream.value([])),
          expensesStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);

      // Initially on Dashboard
      final indexedStackFinder = find.byType(IndexedStack);
      expect(indexedStackFinder, findsOneWidget);
      final indexedStack = tester.widget<IndexedStack>(indexedStackFinder);
      expect(indexedStack.index, 0);

      // Tap Expenses in bottom bar
      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();

      final updatedIndexedStack1 = tester.widget<IndexedStack>(indexedStackFinder);
      expect(updatedIndexedStack1.index, 1);
      expect(find.text('No expenses recorded yet'), findsOneWidget);

      // Tap Transactions in bottom bar
      await tester.tap(find.text('Transactions'));
      await tester.pumpAndSettle();

      final updatedIndexedStack2 = tester.widget<IndexedStack>(indexedStackFinder);
      expect(updatedIndexedStack2.index, 2);

      // Tap Home in bottom bar
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      final updatedIndexedStack3 = tester.widget<IndexedStack>(indexedStackFinder);
      expect(updatedIndexedStack3.index, 0);
    });
  });
}

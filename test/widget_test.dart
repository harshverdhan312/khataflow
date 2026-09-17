import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/app/app.dart';
import 'package:khata_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:khata_flow/features/dashboard/presentation/dashboard_providers.dart';

import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/merchant/presentation/merchant_providers.dart';
import 'package:khata_flow/features/transactions/presentation/transactions_providers.dart';

void main() {
  testWidgets('KhataFlowApp boots up to dashboard screen', (WidgetTester tester) async {
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
          inactiveMerchantsStreamProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
          allTransactionsStreamProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
          expensesStreamProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
        ],
        child: const KhataFlowApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('KhataFlow'), findsOneWidget);
    expect(find.text('No store tabs yet'), findsOneWidget);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/app/app.dart';
import 'package:khata_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:khata_flow/features/dashboard/presentation/dashboard_providers.dart';

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

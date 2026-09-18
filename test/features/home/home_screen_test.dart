import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/app/theme/app_colors.dart';
import 'package:khata_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:khata_flow/features/dashboard/domain/expense_dashboard_summary.dart';
import 'package:khata_flow/features/dashboard/presentation/dashboard_providers.dart';
import 'package:khata_flow/features/home/presentation/home_screen.dart';
import 'package:khata_flow/features/navigation/presentation/main_nav_screen.dart';
import 'package:khata_flow/features/voice/presentation/widgets/voice_pulse_mic_button.dart';

void main() {
  group('HomeScreen & VoicePulseMicButton Tests', () {
    testWidgets('renders brand title, central mic, guide text, chips, and balance cards', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final container = ProviderContainer(
        overrides: [
          dashboardSummaryStreamProvider.overrideWith((ref) => Stream.value(
                const DashboardSummary(
                  totalOutstandingPaise: 450000,
                  merchantSummaries: [],
                ),
              )),
          expenseDashboardSummaryProvider.overrideWith((ref) => AsyncValue.data(
                ExpenseDashboardSummary(
                  periodStart: DateTime(now.year, now.month, 1),
                  periodEnd: DateTime(now.year, now.month + 1, 1),
                  totalAmountPaise: 125000,
                  currentMonthExpenseCount: 3,
                  categoryBreakdown: [],
                  recentExpenses: [],
                ),
              )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Branding & titles
      expect(find.text('KhataFlow'), findsOneWidget);

      // Central Mic & Action text
      expect(find.byType(VoicePulseMicButton), findsOneWidget);
      expect(find.text('Tap to speak / add something'), findsOneWidget);

      // Example voice prompt chips
      expect(find.text('"Sharma se doodh 60 liya"'), findsOneWidget);
      expect(find.text('"I spent 250 on food"'), findsOneWidget);

      // Balance Quick Glance cards
      expect(find.text('Total Outstanding'), findsOneWidget);
      expect(find.text('₹4,500'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('₹1,250'), findsOneWidget);
    });

    testWidgets('tapping quick glance cards navigates to respective tab index', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final container = ProviderContainer(
        overrides: [
          dashboardSummaryStreamProvider.overrideWith((ref) => Stream.value(
                const DashboardSummary(
                  totalOutstandingPaise: 50000,
                  merchantSummaries: [],
                ),
              )),
          expenseDashboardSummaryProvider.overrideWith((ref) => AsyncValue.data(
                ExpenseDashboardSummary(
                  periodStart: DateTime(now.year, now.month, 1),
                  periodEnd: DateTime(now.year, now.month + 1, 1),
                  totalAmountPaise: 80000,
                  currentMonthExpenseCount: 2,
                  categoryBreakdown: [],
                  recentExpenses: [],
                ),
              )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Outstanding dues card -> should switch mainNavIndex to 0 (Ledger)
      await tester.tap(find.text('Total Outstanding'));
      await tester.pump();
      expect(container.read(mainNavIndexProvider), 0);

      // Tap Spent card -> should switch mainNavIndex to 2 (Expenses)
      await tester.tap(find.text('This Month'));
      await tester.pump();
      expect(container.read(mainNavIndexProvider), 2);
    });

    testWidgets('VoicePulseMicButton renders pulse animation when listening is true', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.surfaceDark,
            body: Center(
              child: VoicePulseMicButton(
                isListening: true,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VoicePulseMicButton), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(VoicePulseMicButton));
      expect(tapped, isTrue);
    });
  });
}

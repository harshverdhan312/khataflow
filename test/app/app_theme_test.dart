import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/app/app.dart';
import 'package:khata_flow/app/theme/app_colors.dart';
import 'package:khata_flow/app/theme/app_theme.dart';
import 'package:khata_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:khata_flow/features/dashboard/presentation/dashboard_providers.dart';
import 'package:khata_flow/features/expense/presentation/expense_providers.dart';
import 'package:khata_flow/features/merchant/presentation/merchant_providers.dart';
import 'package:khata_flow/features/transactions/presentation/transactions_providers.dart';

void main() {
  group('App Dark Theme Enforcement Tests', () {
    testWidgets('KhataFlowApp configures themeMode as ThemeMode.dark unconditionally', (tester) async {
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

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, equals(ThemeMode.dark));
      expect(materialApp.darkTheme?.brightness, equals(Brightness.dark));
      expect(materialApp.theme?.brightness, equals(Brightness.dark));
    });

    test('AppTheme.darkTheme has dark brightness and proper dark surfaces', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.scaffoldBackgroundColor, equals(AppColors.surfaceDark));
      expect(theme.colorScheme.surface, equals(AppColors.cardDark));
      expect(theme.colorScheme.primary, equals(AppColors.primary));
    });

    test('AppTheme.lightTheme is aliased to darkTheme to prevent light theme leaks', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.brightness, equals(Brightness.dark));
      expect(lightTheme.scaffoldBackgroundColor, equals(AppColors.surfaceDark));
    });
  });
}

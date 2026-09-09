import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/database/database_provider.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/merchant/presentation/add_merchant_screen.dart';
import 'package:khata_flow/features/merchant/presentation/merchant_providers.dart';

void main() {
  testWidgets('AddMerchantScreen validates form and creates merchant', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AddMerchantScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Store Details'), findsOneWidget);
    expect(find.text('Save Store Tab'), findsOneWidget);

    // Enter name
    await tester.enterText(find.byType(TextFormField).first, 'Gupta Milk Dairy');
    // Enter VPA
    await tester.enterText(find.byType(TextFormField).at(1), 'gupta@paytm');
    // Select category Milk & Dairy
    await tester.tap(find.text('Milk & Dairy'));
    await tester.pump();

    // Tap Save Store Tab
    await tester.tap(find.text('Save Store Tab'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify merchant created in database
    final merchantRepo = container.read(merchantRepositoryProvider);
    final merchants = await merchantRepo.getActiveMerchants();
    expect(merchants.length, 1);
    expect(merchants.first.name, 'Gupta Milk Dairy');
    expect(merchants.first.category, MerchantCategory.milk);
    expect(merchants.first.upiVpa, 'gupta@paytm');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    container.dispose();
    await db.close();
  });
}

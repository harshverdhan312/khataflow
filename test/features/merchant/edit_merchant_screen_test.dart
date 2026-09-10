import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/merchant/domain/merchant_repository.dart';
import 'package:khata_flow/features/merchant/presentation/edit_merchant_screen.dart';
import 'package:khata_flow/features/merchant/presentation/merchant_providers.dart';

class MockMerchantRepository implements MerchantRepository {
  Merchant? merchant;
  Merchant? updatedMerchant;

  MockMerchantRepository(this.merchant);

  @override
  Stream<List<Merchant>> watchActiveMerchants() => Stream.value(merchant != null ? [merchant!] : []);

  @override
  Stream<List<Merchant>> watchInactiveMerchants() => Stream.value([]);

  @override
  Future<List<Merchant>> getActiveMerchants() async => merchant != null ? [merchant!] : [];

  @override
  Future<Merchant?> getMerchantById(String id) async => merchant;

  @override
  Future<Merchant> createMerchant(CreateMerchantInput input) async => throw UnimplementedError();

  @override
  Future<void> updateMerchant(Merchant merchant) async {
    updatedMerchant = merchant;
    this.merchant = merchant;
  }

  @override
  Future<void> deactivateMerchant(String merchantId) async {}

  @override
  Future<void> reactivateMerchant(String merchantId) async {}
}

void main() {
  testWidgets('EditMerchantScreen loads initial merchant data and allows submitting updates', (tester) async {
    final now = DateTime.now();
    final initialMerchant = Merchant(
      id: 'm1',
      name: 'Sharma General Store',
      category: MerchantCategory.grocery,
      upiVpa: 'sharma@okhdfcbank',
      phone: '9876543210',
      createdAt: now,
      updatedAt: now,
    );

    final mockRepo = MockMerchantRepository(initialMerchant);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantRepositoryProvider.overrideWithValue(mockRepo),
          merchantDetailProvider('m1').overrideWith((ref) => Future.value(initialMerchant)),
        ],
        child: const MaterialApp(
          home: EditMerchantScreen(merchantId: 'm1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial values prefilled
    expect(find.text('Sharma General Store'), findsOneWidget);
    expect(find.text('sharma@okhdfcbank'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);

    // Edit store name
    await tester.enterText(find.widgetWithText(TextFormField, 'Store / Merchant Name *'), 'Sharma Super Store');

    // Submit form
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // Verify update was sent to repository
    expect(mockRepo.updatedMerchant, isNotNull);
    expect(mockRepo.updatedMerchant!.name, 'Sharma Super Store');
    expect(mockRepo.updatedMerchant!.upiVpa, 'sharma@okhdfcbank');
  });
}

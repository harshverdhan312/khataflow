import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/voice/domain/merchant_resolver.dart';

void main() {
  const resolver = MerchantResolver();

  final activeMerchants = [
    Merchant(
      id: 'm1',
      name: 'Sharma General Store',
      category: MerchantCategory.grocery,
      phone: '9876543210',
      upiVpa: 'sharma@upi',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Merchant(
      id: 'm2',
      name: 'Sharma Sweets',
      category: MerchantCategory.other,
      phone: '9876543211',
      upiVpa: 'sharmasweets@upi',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Merchant(
      id: 'm3',
      name: 'Gupta Traders',
      category: MerchantCategory.grocery,
      phone: '9876543212',
      upiVpa: 'gupta@upi',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Merchant(
      id: 'm4',
      name: 'Venkateshwara Store',
      category: MerchantCategory.milk,
      phone: '9876543213',
      upiVpa: 'venkat@upi',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  group('MerchantResolver Tests', () {
    test('resolves exact match regardless of case', () {
      final result = resolver.resolve(
        query: 'Gupta Traders',
        activeMerchants: activeMerchants,
      );

      expect(result, isA<ExactMerchantMatch>());
      expect((result as ExactMerchantMatch).merchant.id, equals('m3'));
    });

    test('resolves unique prefix match', () {
      final result = resolver.resolve(
        query: 'Venkateshwara',
        activeMerchants: activeMerchants,
      );

      expect(result, isA<ExactMerchantMatch>());
      expect((result as ExactMerchantMatch).merchant.id, equals('m4'));
    });

    test('detects ambiguous match when multiple stores share common prefix/word', () {
      final result = resolver.resolve(
        query: 'Sharma',
        activeMerchants: activeMerchants,
      );

      expect(result, isA<AmbiguousMerchantMatch>());
      final ambiguous = result as AmbiguousMerchantMatch;
      expect(ambiguous.candidates.length, equals(2));
      expect(ambiguous.candidates.map((m) => m.id), containsAll(['m1', 'm2']));
    });

    test('resolves exact match when full distinctive name is provided despite shared prefix', () {
      final result = resolver.resolve(
        query: 'Sharma Sweets',
        activeMerchants: activeMerchants,
      );

      expect(result, isA<ExactMerchantMatch>());
      expect((result as ExactMerchantMatch).merchant.id, equals('m2'));
    });

    test('returns NoMerchantMatch when query does not match any active store', () {
      final result = resolver.resolve(
        query: 'Patel Electronics',
        activeMerchants: activeMerchants,
      );

      expect(result, isA<NoMerchantMatch>());
      expect((result as NoMerchantMatch).query, equals('Patel Electronics'));
    });

    test('returns NoMerchantMatch for empty query or empty merchant list', () {
      final r1 = resolver.resolve(query: '', activeMerchants: activeMerchants);
      expect(r1, isA<NoMerchantMatch>());

      final r2 = resolver.resolve(query: 'Sharma', activeMerchants: const []);
      expect(r2, isA<NoMerchantMatch>());
    });
  });
}

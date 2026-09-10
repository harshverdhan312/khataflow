import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/errors/app_exceptions.dart';
import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/features/merchant/data/merchant_repository_impl.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/shared/models/sync_enums.dart';

void main() {
  late AppDatabase db;
  late MerchantRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = MerchantRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MerchantRepository Tests', () {
    test('creates merchant and creates atomic sync queue entry', () async {
      final input = CreateMerchantInput(
        name: 'Sharma Kirana',
        category: MerchantCategory.grocery,
        phone: '9876543210',
        upiVpa: 'sharma@upi',
      );

      final merchant = await repository.createMerchant(input);
      expect(merchant.id, isNotEmpty);
      expect(merchant.name, 'Sharma Kirana');
      expect(merchant.category, MerchantCategory.grocery);
      expect(merchant.phone, '9876543210');
      expect(merchant.upiVpa, 'sharma@upi');
      expect(merchant.isActive, true);

      // Verify sync queue outbox entry
      final queueItems = await db.syncQueueDao.getPendingItems();
      expect(queueItems.length, 1);
      expect(queueItems.first.entityId, merchant.id);
      expect(queueItems.first.entityType, SyncEntityType.merchant.toDbValue());
      expect(queueItems.first.operation, SyncOperation.upsert.toDbValue());

      // Verify active merchants retrieval
      final active = await repository.getActiveMerchants();
      expect(active.length, 1);
      expect(active.first.id, merchant.id);
    });

    test('validates merchant input before creation', () async {
      // Invalid name
      expect(
        () => repository.createMerchant(
          const CreateMerchantInput(
            name: '',
            category: MerchantCategory.grocery,
            upiVpa: 'valid@upi',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      // Invalid VPA
      expect(
        () => repository.createMerchant(
          const CreateMerchantInput(
            name: 'Valid Store',
            category: MerchantCategory.grocery,
            upiVpa: 'invalid-vpa-without-at',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('deactivates merchant and enqueues sync update', () async {
      final merchant = await repository.createMerchant(
        const CreateMerchantInput(
          name: 'Gupta Milk Dairy',
          category: MerchantCategory.milk,
          upiVpa: 'gupta@upi',
        ),
      );

      expect((await repository.getActiveMerchants()).length, 1);

      // Deactivate
      await repository.deactivateMerchant(merchant.id);

      // Should no longer appear in active list
      final active = await repository.getActiveMerchants();
      expect(active.isEmpty, true);

      // Sync queue should have 2 entries (create + deactivate update)
      final queueItems = await db.syncQueueDao.getPendingItems();
      expect(queueItems.length, 2);

      // Should appear in inactive stream
      final inactiveList = await repository.watchInactiveMerchants().first;
      expect(inactiveList.length, 1);
      expect(inactiveList.first.id, merchant.id);

      // Reactivate
      await repository.reactivateMerchant(merchant.id);
      final activeAfterReactivation = await repository.getActiveMerchants();
      expect(activeAfterReactivation.length, 1);
      expect(activeAfterReactivation.first.id, merchant.id);
    });

    test('updates merchant details and preserves data integrity', () async {
      final merchant = await repository.createMerchant(
        const CreateMerchantInput(
          name: 'Original Store',
          category: MerchantCategory.grocery,
          phone: '9876543210',
          upiVpa: 'store@upi',
        ),
      );

      final updated = merchant.copyWith(
        name: 'Updated Store Name',
        category: MerchantCategory.milk,
        phone: '9123456780',
        upiVpa: 'newstore@upi',
      );

      await repository.updateMerchant(updated);

      final fetched = await repository.getMerchantById(merchant.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Updated Store Name');
      expect(fetched.category, MerchantCategory.milk);
      expect(fetched.phone, '9123456780');
      expect(fetched.upiVpa, 'newstore@upi');
      expect(fetched.isActive, true);
    });
  });
}

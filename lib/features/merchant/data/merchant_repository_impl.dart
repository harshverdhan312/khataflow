import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/validators.dart';
import '../../../database/app_database.dart';
import '../../../shared/models/sync_enums.dart';
import '../domain/merchant.dart';
import '../domain/merchant_category.dart';
import '../domain/merchant_repository.dart';

class MerchantRepositoryImpl implements MerchantRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  MerchantRepositoryImpl(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  @override
  Stream<List<Merchant>> watchActiveMerchants() {
    return _db.merchantDao.watchActiveMerchants().map(
          (entities) => entities.map(_mapEntityToDomain).toList(),
        );
  }

  @override
  Stream<List<Merchant>> watchInactiveMerchants() {
    return _db.merchantDao.watchInactiveMerchants().map(
          (entities) => entities.map(_mapEntityToDomain).toList(),
        );
  }

  @override
  Future<List<Merchant>> getActiveMerchants() async {
    final entities = await _db.merchantDao.getActiveMerchants();
    return entities.map(_mapEntityToDomain).toList();
  }

  @override
  Future<Merchant?> getMerchantById(String id) async {
    final entity = await _db.merchantDao.getMerchantById(id);
    if (entity == null) return null;
    return _mapEntityToDomain(entity);
  }

  @override
  Future<Merchant> createMerchant(CreateMerchantInput input) async {
    // Domain validations
    final nameError = Validators.validateMerchantName(input.name);
    if (nameError != null) throw ValidationException(nameError);

    final vpaError = Validators.validateUpiVpa(input.upiVpa);
    if (vpaError != null) throw ValidationException(vpaError);

    final phoneError = Validators.validatePhone(input.phone);
    if (phoneError != null) throw ValidationException(phoneError);

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanPhone = input.phone?.trim().isNotEmpty == true ? input.phone!.trim() : null;

    final merchantCompanion = MerchantsCompanion(
      id: Value(id),
      name: Value(input.name.trim()),
      category: Value(input.category.toDbValue()),
      phone: Value(cleanPhone),
      upiVpa: Value(input.upiVpa.trim()),
      createdAt: Value(now),
      updatedAt: Value(now),
      isActive: const Value(true),
    );

    final syncQueueCompanion = SyncQueueCompanion(
      id: Value(_uuid.v4()),
      entityType: Value(SyncEntityType.merchant.toDbValue()),
      entityId: Value(id),
      operation: Value(SyncOperation.upsert.toDbValue()),
      createdAt: Value(now),
    );

    // Atomic SQLite write: insert merchant + outbox queue item
    await _db.transaction(() async {
      await _db.merchantDao.insertMerchant(merchantCompanion);
      await _db.syncQueueDao.enqueue(syncQueueCompanion);
    });

    return Merchant(
      id: id,
      name: input.name.trim(),
      category: input.category,
      phone: cleanPhone,
      upiVpa: input.upiVpa.trim(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      isActive: true,
    );
  }

  @override
  Future<void> updateMerchant(Merchant merchant) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = MerchantsCompanion(
      id: Value(merchant.id),
      name: Value(merchant.name),
      category: Value(merchant.category.toDbValue()),
      phone: Value(merchant.phone),
      upiVpa: Value(merchant.upiVpa),
      createdAt: Value(merchant.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(now),
      isActive: Value(merchant.isActive),
    );

    final syncQueueCompanion = SyncQueueCompanion(
      id: Value(_uuid.v4()),
      entityType: Value(SyncEntityType.merchant.toDbValue()),
      entityId: Value(merchant.id),
      operation: Value(SyncOperation.upsert.toDbValue()),
      createdAt: Value(now),
    );

    await _db.transaction(() async {
      await _db.merchantDao.updateMerchant(companion);
      await _db.syncQueueDao.enqueue(syncQueueCompanion);
    });
  }

  @override
  Future<void> deactivateMerchant(String merchantId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final syncQueueCompanion = SyncQueueCompanion(
      id: Value(_uuid.v4()),
      entityType: Value(SyncEntityType.merchant.toDbValue()),
      entityId: Value(merchantId),
      operation: Value(SyncOperation.upsert.toDbValue()),
      createdAt: Value(now),
    );

    await _db.transaction(() async {
      await _db.merchantDao.deactivateMerchant(merchantId, now);
      await _db.syncQueueDao.enqueue(syncQueueCompanion);
    });
  }

  @override
  Future<void> reactivateMerchant(String merchantId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final syncQueueCompanion = SyncQueueCompanion(
      id: Value(_uuid.v4()),
      entityType: Value(SyncEntityType.merchant.toDbValue()),
      entityId: Value(merchantId),
      operation: Value(SyncOperation.upsert.toDbValue()),
      createdAt: Value(now),
    );

    await _db.transaction(() async {
      await _db.merchantDao.reactivateMerchant(merchantId, now);
      await _db.syncQueueDao.enqueue(syncQueueCompanion);
    });
  }

  Merchant _mapEntityToDomain(MerchantEntity entity) {
    return Merchant(
      id: entity.id,
      name: entity.name,
      category: MerchantCategory.fromDbValue(entity.category),
      phone: entity.phone,
      upiVpa: entity.upiVpa,
      createdAt: DateTime.fromMillisecondsSinceEpoch(entity.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(entity.updatedAt),
      isActive: entity.isActive,
    );
  }
}

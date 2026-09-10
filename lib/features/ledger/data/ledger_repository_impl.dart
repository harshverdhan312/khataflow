import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/validators.dart';
import '../../../database/app_database.dart';
import '../../../shared/models/sync_enums.dart';
import '../domain/ledger_repository.dart';
import '../domain/purchase.dart';

class LedgerRepositoryImpl implements LedgerRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  LedgerRepositoryImpl(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  @override
  Stream<List<Purchase>> watchPurchases(String merchantId) {
    return _db.purchaseDao.watchPurchasesWithSettledStatus(merchantId).map(
          (items) => items.map((item) => _mapEntityToDomain(item.purchase, isSettled: item.isSettled)).toList(),
        );
  }

  @override
  Future<List<Purchase>> getPurchases(String merchantId) async {
    final items = await _db.purchaseDao.getPurchasesWithSettledStatus(merchantId);
    return items.map((item) => _mapEntityToDomain(item.purchase, isSettled: item.isSettled)).toList();
  }

  @override
  Stream<int> watchOutstandingAmount(String merchantId) {
    return _db.purchaseDao.watchOutstandingAmount(merchantId);
  }

  @override
  Future<int> getOutstandingAmount(String merchantId) {
    return _db.purchaseDao.getOutstandingAmount(merchantId);
  }

  @override
  Stream<int> watchTotalOutstanding() {
    return _db.purchaseDao.watchTotalOutstanding();
  }

  @override
  Future<int> getTotalOutstanding() {
    return _db.purchaseDao.getTotalOutstanding();
  }

  @override
  Future<List<Purchase>> getUnsettledPurchases(String merchantId) async {
    final entities = await _db.purchaseDao.getUnsettledPurchases(merchantId);
    return entities.map(_mapEntityToDomain).toList();
  }

  @override
  Future<Purchase> addPurchase(CreatePurchaseInput input) async {
    // Validations
    if (input.merchantId.trim().isEmpty) {
      throw const ValidationException('Merchant ID is required');
    }
    if (input.amountPaise <= 0) {
      throw const InvalidAmountException('Purchase amount must be greater than zero');
    }
    final noteError = Validators.validatePurchaseNote(input.note);
    if (noteError != null) {
      throw ValidationException(noteError);
    }

    final merchant = await _db.merchantDao.getMerchantById(input.merchantId);
    if (merchant == null) {
      throw const MerchantNotFoundException();
    }

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final purchaseDateMs = input.purchaseDate.millisecondsSinceEpoch;

    final purchaseCompanion = PurchasesCompanion(
      id: Value(id),
      merchantId: Value(input.merchantId),
      amountPaise: Value(input.amountPaise),
      note: Value(input.note.trim()),
      category: Value(input.category?.trim()),
      purchaseDate: Value(purchaseDateMs),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: Value(SyncStatus.pending.toDbValue()),
    );

    final syncQueueCompanion = SyncQueueCompanion(
      id: Value(_uuid.v4()),
      entityType: Value(SyncEntityType.purchase.toDbValue()),
      entityId: Value(id),
      operation: Value(SyncOperation.upsert.toDbValue()),
      createdAt: Value(now),
    );

    // Atomic SQLite write: insert purchase + outbox queue item
    await _db.transaction(() async {
      await _db.purchaseDao.insertPurchase(purchaseCompanion);
      await _db.syncQueueDao.enqueue(syncQueueCompanion);
    });

    return Purchase(
      id: id,
      merchantId: input.merchantId,
      amountPaise: input.amountPaise,
      note: input.note.trim(),
      category: input.category?.trim(),
      purchaseDate: input.purchaseDate,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      syncStatus: SyncStatus.pending,
    );
  }

  Purchase _mapEntityToDomain(PurchaseEntity entity, {bool isSettled = false}) {
    return Purchase(
      id: entity.id,
      merchantId: entity.merchantId,
      amountPaise: entity.amountPaise,
      note: entity.note,
      category: entity.category,
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(entity.purchaseDate),
      createdAt: DateTime.fromMillisecondsSinceEpoch(entity.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(entity.updatedAt),
      syncStatus: SyncStatus.fromDbValue(entity.syncStatus),
      isSettled: isSettled,
    );
  }
}

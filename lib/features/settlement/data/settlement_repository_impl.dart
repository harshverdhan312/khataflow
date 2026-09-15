import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../database/app_database.dart';
import '../../../shared/models/sync_enums.dart';
import '../../receipt/domain/settlement_receipt.dart';
import '../domain/settlement.dart';
import '../domain/settlement_item.dart';
import '../domain/settlement_repository.dart';
import '../domain/settlement_status.dart';


class SettlementRepositoryImpl implements SettlementRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  SettlementRepositoryImpl(this._db, [this._uuid = const Uuid()]);

  @override
  Future<Settlement> recordSettlement({
    required String merchantId,
    required List<String> purchaseIds,
    String? paymentReference,
  }) async {
    if (purchaseIds.isEmpty) {
      throw ArgumentError('Cannot record settlement without purchases.');
    }

    final merchant = await _db.merchantDao.getMerchantById(merchantId);
    if (merchant == null) {
      throw ArgumentError('Merchant $merchantId does not exist.');
    }

    final unsettledPurchases = await _db.purchaseDao.getUnsettledPurchases(merchantId);
    final purchaseMap = {for (final p in unsettledPurchases) p.id: p};

    final itemsToSettle = <SettlementItemsCompanion>[];
    int totalAmountPaise = 0;

    final settlementId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final purchaseId in purchaseIds) {
      final purchase = purchaseMap[purchaseId];
      if (purchase == null) {
        throw ArgumentError(
          'Purchase $purchaseId is either already settled or does not belong to merchant $merchantId.',
        );
      }
      totalAmountPaise += purchase.amountPaise;
      itemsToSettle.add(
        SettlementItemsCompanion.insert(
          settlementId: settlementId,
          purchaseId: purchaseId,
          amountPaise: purchase.amountPaise,
        ),
      );
    }

    if (totalAmountPaise <= 0) {
      throw ArgumentError('Settlement amount must be greater than zero.');
    }

    final settlementCompanion = SettlementsCompanion.insert(
      id: settlementId,
      merchantId: merchantId,
      amountPaise: totalAmountPaise,
      status: SettlementStatus.settled.toDbValue(),
      utr: (paymentReference != null && paymentReference.trim().isNotEmpty)
          ? Value(paymentReference.trim())
          : const Value.absent(),
      initiatedAt: now,
      completedAt: Value(now),
      createdAt: now,
      updatedAt: now,
      syncStatus: const Value('PENDING'),
    );

    final syncEntry = SyncQueueCompanion.insert(
      id: _uuid.v4(),
      entityType: 'SETTLEMENT',
      entityId: settlementId,
      operation: 'INSERT',
      createdAt: now,
    );

    await _db.settlementDao.insertSettlementWithItemsAndSync(
      settlement: settlementCompanion,
      items: itemsToSettle,
      syncEntry: syncEntry,
    );

    final domainItems = itemsToSettle
        .map(
          (item) => SettlementItem(
            settlementId: settlementId,
            purchaseId: item.purchaseId.value,
            amountPaise: item.amountPaise.value,
          ),
        )
        .toList();

    return Settlement(
      id: settlementId,
      merchantId: merchantId,
      amountPaise: totalAmountPaise,
      status: SettlementStatus.settled,
      utr: (paymentReference != null && paymentReference.trim().isNotEmpty)
          ? paymentReference.trim()
          : null,
      initiatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      completedAt: DateTime.fromMillisecondsSinceEpoch(now),
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      syncStatus: SyncStatus.pending,
      items: domainItems,
    );
  }

  @override
  Future<Settlement> initiateSettlement({
    required String merchantId,
    required List<String> purchaseIds,
  }) async {
    if (purchaseIds.isEmpty) {
      throw ArgumentError('Cannot initiate settlement without purchases.');
    }

    // 1. Guard against duplicate / overlapping unresolved settlements
    final unresolved = await _db.settlementDao.getUnresolvedSettlements(merchantId: merchantId);
    if (unresolved.isNotEmpty) {
      throw StateError(
        'An unresolved settlement (${unresolved.first.id}) already exists for this merchant. Please resolve it first.',
      );
    }

    // 2. Fetch unsettled purchases to verify and compute total paise amount
    final unsettledPurchases = await _db.purchaseDao.getUnsettledPurchases(merchantId);
    final purchaseMap = {for (final p in unsettledPurchases) p.id: p};

    final itemsToSettle = <SettlementItemsCompanion>[];
    int totalAmountPaise = 0;

    final settlementId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final purchaseId in purchaseIds) {
      final purchase = purchaseMap[purchaseId];
      if (purchase == null) {
        throw ArgumentError(
          'Purchase $purchaseId is either already settled or does not belong to merchant $merchantId.',
        );
      }
      totalAmountPaise += purchase.amountPaise;
      itemsToSettle.add(
        SettlementItemsCompanion.insert(
          settlementId: settlementId,
          purchaseId: purchaseId,
          amountPaise: purchase.amountPaise,
        ),
      );
    }

    if (totalAmountPaise <= 0) {
      throw ArgumentError('Settlement amount must be greater than zero.');
    }

    final settlementCompanion = SettlementsCompanion.insert(
      id: settlementId,
      merchantId: merchantId,
      amountPaise: totalAmountPaise,
      status: SettlementStatus.initiated.toDbValue(),
      initiatedAt: now,
      createdAt: now,
      updatedAt: now,
      syncStatus: const Value('PENDING'),
    );

    final syncEntry = SyncQueueCompanion.insert(
      id: _uuid.v4(),
      entityType: 'SETTLEMENT',
      entityId: settlementId,
      operation: 'INSERT',
      createdAt: now,
    );

    // 3. Atomically persist settlement, settlement items, and sync queue entry
    await _db.settlementDao.insertSettlementWithItemsAndSync(
      settlement: settlementCompanion,
      items: itemsToSettle,
      syncEntry: syncEntry,
    );

    final domainItems = itemsToSettle
        .map(
          (item) => SettlementItem(
            settlementId: settlementId,
            purchaseId: item.purchaseId.value,
            amountPaise: item.amountPaise.value,
          ),
        )
        .toList();

    return Settlement(
      id: settlementId,
      merchantId: merchantId,
      amountPaise: totalAmountPaise,
      status: SettlementStatus.initiated,
      initiatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      syncStatus: SyncStatus.pending,
      items: domainItems,
    );
  }

  @override
  Future<void> updateSettlementStatus({
    required String settlementId,
    required SettlementStatus status,
    String? transactionId,
    String? utr,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isTerminal = status.isTerminal;

    await _db.settlementDao.updateSettlementStatus(
      settlementId: settlementId,
      status: status.toDbValue(),
      transactionId: transactionId,
      utr: utr,
      completedAt: isTerminal ? now : null,
      updatedAt: now,
    );
  }

  @override
  Future<void> markSettlementSettled({
    required String settlementId,
    String? transactionId,
    String? utr,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.settlementDao.updateSettlementStatus(
      settlementId: settlementId,
      status: SettlementStatus.settled.toDbValue(),
      transactionId: transactionId,
      utr: utr,
      completedAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> markSettlementFailed({
    required String settlementId,
    required String reason,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.settlementDao.updateSettlementStatus(
      settlementId: settlementId,
      status: SettlementStatus.failed.toDbValue(),
      completedAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> markSettlementUnknown({
    required String settlementId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.settlementDao.updateSettlementStatus(
      settlementId: settlementId,
      status: SettlementStatus.unknown.toDbValue(),
      updatedAt: now,
    );
  }

  @override
  Future<Settlement?> getSettlementById(String settlementId) async {
    final entity = await _db.settlementDao.getSettlementById(settlementId);
    if (entity == null) return null;

    final itemEntities = await _db.settlementDao.getSettlementItems(settlementId);
    final items = itemEntities
        .map(
          (e) => SettlementItem(
            settlementId: e.settlementId,
            purchaseId: e.purchaseId,
            amountPaise: e.amountPaise,
          ),
        )
        .toList();

    return _mapEntityToDomain(entity, items);
  }

  @override
  Future<SettlementReceipt?> getSettlementReceipt(String settlementId) async {
    final entity = await _db.settlementDao.getSettlementById(settlementId);
    if (entity == null) return null;

    final status = SettlementStatus.fromDbValue(entity.status);
    if (status != SettlementStatus.settled) {
      return null;
    }

    final merchant = await _db.merchantDao.getMerchantById(entity.merchantId);
    final merchantName = merchant?.name ?? 'Unknown Merchant';
    final merchantUpiVpa = merchant?.upiVpa ?? '';

    final itemEntities = await _db.settlementDao.getSettlementItems(settlementId);
    final purchaseItems = <ReceiptPurchaseItem>[];

    for (final item in itemEntities) {
      final purchase = await _db.purchaseDao.getPurchaseById(item.purchaseId);
      if (purchase != null) {
        purchaseItems.add(
          ReceiptPurchaseItem(
            purchaseId: purchase.id,
            note: purchase.note,
            amountPaise: item.amountPaise,
            purchaseDate: DateTime.fromMillisecondsSinceEpoch(purchase.purchaseDate),
            category: purchase.category,
          ),
        );
      } else {
        purchaseItems.add(
          ReceiptPurchaseItem(
            purchaseId: item.purchaseId,
            note: 'Settled Item',
            amountPaise: item.amountPaise,
            purchaseDate: DateTime.fromMillisecondsSinceEpoch(entity.initiatedAt),
          ),
        );
      }
    }

    final totalSettledPaise = entity.amountPaise;
    final settlementDate = entity.completedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(entity.completedAt!)
        : DateTime.fromMillisecondsSinceEpoch(entity.initiatedAt);

    return SettlementReceipt(
      settlementId: entity.id,
      merchantId: entity.merchantId,
      merchantName: merchantName,
      merchantUpiVpa: merchantUpiVpa,
      amountPaise: entity.amountPaise,
      status: entity.status,
      settlementDate: settlementDate,
      utr: (entity.utr != null && entity.utr!.isNotEmpty) ? entity.utr : null,
      transactionId: (entity.transactionId != null && entity.transactionId!.isNotEmpty)
          ? entity.transactionId
          : null,
      items: purchaseItems,
      totalSettledPaise: totalSettledPaise,
    );
  }


  @override
  Future<List<Settlement>> getUnresolvedSettlements({String? merchantId}) async {
    final entities = await _db.settlementDao.getUnresolvedSettlements(merchantId: merchantId);
    final results = <Settlement>[];

    for (final entity in entities) {
      final itemEntities = await _db.settlementDao.getSettlementItems(entity.id);
      final items = itemEntities
          .map(
            (e) => SettlementItem(
              settlementId: e.settlementId,
              purchaseId: e.purchaseId,
              amountPaise: e.amountPaise,
            ),
          )
          .toList();
      results.add(_mapEntityToDomain(entity, items));
    }

    return results;
  }

  @override
  Future<bool> hasUnresolvedSettlementForMerchant(String merchantId) async {
    final unresolved = await _db.settlementDao.getUnresolvedSettlements(merchantId: merchantId);
    return unresolved.isNotEmpty;
  }

  @override
  Future<List<String>> getUnresolvedPurchaseIds(String merchantId) {
    return _db.settlementDao.getUnresolvedPurchaseIds(merchantId);
  }

  @override
  Stream<List<Settlement>> watchSettlementsForMerchant(String merchantId) {
    return _db.settlementDao.watchSettlementsForMerchant(merchantId).asyncMap((entities) async {
      final settlements = <Settlement>[];
      for (final entity in entities) {
        final itemEntities = await _db.settlementDao.getSettlementItems(entity.id);
        final items = itemEntities
            .map(
              (e) => SettlementItem(
                settlementId: e.settlementId,
                purchaseId: e.purchaseId,
                amountPaise: e.amountPaise,
              ),
            )
            .toList();
        settlements.add(_mapEntityToDomain(entity, items));
      }
      return settlements;
    });
  }

  @override
  Stream<List<Settlement>> watchAllSettlements() {
    return _db.settlementDao.watchAllSettlements().asyncMap((entities) async {
      final settlements = <Settlement>[];
      for (final entity in entities) {
        final itemEntities = await _db.settlementDao.getSettlementItems(entity.id);
        final items = itemEntities
            .map(
              (e) => SettlementItem(
                settlementId: e.settlementId,
                purchaseId: e.purchaseId,
                amountPaise: e.amountPaise,
              ),
            )
            .toList();
        settlements.add(_mapEntityToDomain(entity, items));
      }
      return settlements;
    });
  }

  @override
  Future<List<Settlement>> getAllSettlements() async {
    final entities = await _db.settlementDao.getAllSettlements();
    final settlements = <Settlement>[];
    for (final entity in entities) {
      final itemEntities = await _db.settlementDao.getSettlementItems(entity.id);
      final items = itemEntities
          .map(
            (e) => SettlementItem(
              settlementId: e.settlementId,
              purchaseId: e.purchaseId,
              amountPaise: e.amountPaise,
            ),
          )
          .toList();
      settlements.add(_mapEntityToDomain(entity, items));
    }
    return settlements;
  }

  Settlement _mapEntityToDomain(SettlementEntity entity, List<SettlementItem> items) {
    return Settlement(
      id: entity.id,
      merchantId: entity.merchantId,
      amountPaise: entity.amountPaise,
      status: SettlementStatus.fromDbValue(entity.status),
      transactionId: entity.transactionId,
      utr: entity.utr,
      initiatedAt: DateTime.fromMillisecondsSinceEpoch(entity.initiatedAt),
      completedAt: entity.completedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(entity.completedAt!)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(entity.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(entity.updatedAt),
      syncStatus: SyncStatus.fromDbValue(entity.syncStatus),
      items: items,
    );
  }
}

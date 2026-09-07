// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_dao.dart';

// ignore_for_file: type=lint
mixin _$PurchaseDaoMixin on DatabaseAccessor<AppDatabase> {
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $SettlementsTable get settlements => attachedDatabase.settlements;
  $SettlementItemsTable get settlementItems => attachedDatabase.settlementItems;
  $MerchantsTable get merchants => attachedDatabase.merchants;
  PurchaseDaoManager get managers => PurchaseDaoManager(this);
}

class PurchaseDaoManager {
  final _$PurchaseDaoMixin _db;
  PurchaseDaoManager(this._db);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db.attachedDatabase, _db.purchases);
  $$SettlementsTableTableManager get settlements =>
      $$SettlementsTableTableManager(_db.attachedDatabase, _db.settlements);
  $$SettlementItemsTableTableManager get settlementItems =>
      $$SettlementItemsTableTableManager(
        _db.attachedDatabase,
        _db.settlementItems,
      );
  $$MerchantsTableTableManager get merchants =>
      $$MerchantsTableTableManager(_db.attachedDatabase, _db.merchants);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settlement_dao.dart';

// ignore_for_file: type=lint
mixin _$SettlementDaoMixin on DatabaseAccessor<AppDatabase> {
  $SettlementsTable get settlements => attachedDatabase.settlements;
  $SettlementItemsTable get settlementItems => attachedDatabase.settlementItems;
  SettlementDaoManager get managers => SettlementDaoManager(this);
}

class SettlementDaoManager {
  final _$SettlementDaoMixin _db;
  SettlementDaoManager(this._db);
  $$SettlementsTableTableManager get settlements =>
      $$SettlementsTableTableManager(_db.attachedDatabase, _db.settlements);
  $$SettlementItemsTableTableManager get settlementItems =>
      $$SettlementItemsTableTableManager(
        _db.attachedDatabase,
        _db.settlementItems,
      );
}

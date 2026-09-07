// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merchant_dao.dart';

// ignore_for_file: type=lint
mixin _$MerchantDaoMixin on DatabaseAccessor<AppDatabase> {
  $MerchantsTable get merchants => attachedDatabase.merchants;
  MerchantDaoManager get managers => MerchantDaoManager(this);
}

class MerchantDaoManager {
  final _$MerchantDaoMixin _db;
  MerchantDaoManager(this._db);
  $$MerchantsTableTableManager get merchants =>
      $$MerchantsTableTableManager(_db.attachedDatabase, _db.merchants);
}

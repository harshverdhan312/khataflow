import 'package:drift/drift.dart';
import 'merchants_table.dart';

@DataClassName('SettlementEntity')
class Settlements extends Table {
  TextColumn get id => text()();
  TextColumn get merchantId => text().references(Merchants, #id)();
  IntColumn get amountPaise => integer()();
  TextColumn get status => text()();
  TextColumn get transactionId => text().nullable()();
  TextColumn get utr => text().nullable()();
  IntColumn get initiatedAt => integer()();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();

  @override
  Set<Column> get primaryKey => {id};
}

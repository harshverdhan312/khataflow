import 'package:drift/drift.dart';
import 'merchants_table.dart';

@DataClassName('PurchaseEntity')
class Purchases extends Table {
  TextColumn get id => text()();
  TextColumn get merchantId => text().references(Merchants, #id)();
  IntColumn get amountPaise => integer()();
  TextColumn get note => text()();
  TextColumn get category => text().nullable()();
  IntColumn get purchaseDate => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();

  @override
  Set<Column> get primaryKey => {id};
}

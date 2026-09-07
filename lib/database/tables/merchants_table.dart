import 'package:drift/drift.dart';

@DataClassName('MerchantEntity')
class Merchants extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get upiVpa => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

import 'package:drift/drift.dart';
import 'purchases_table.dart';
import 'settlements_table.dart';

@DataClassName('SettlementItemEntity')
class SettlementItems extends Table {
  TextColumn get settlementId => text().references(Settlements, #id)();
  TextColumn get purchaseId => text().references(Purchases, #id)();
  IntColumn get amountPaise => integer()();

  @override
  Set<Column> get primaryKey => {settlementId, purchaseId};
}

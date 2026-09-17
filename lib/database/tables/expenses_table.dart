import 'package:drift/drift.dart';

@DataClassName('ExpenseEntity')
class Expenses extends Table {
  TextColumn get id => text()();
  IntColumn get amountPaise => integer()();
  TextColumn get category => text()();
  TextColumn get note => text().nullable()();
  IntColumn get expenseDate => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();

  @override
  Set<Column> get primaryKey => {id};
}

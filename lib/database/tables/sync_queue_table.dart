import 'package:drift/drift.dart';

@DataClassName('SyncQueueEntity')
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  IntColumn get lastAttemptAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

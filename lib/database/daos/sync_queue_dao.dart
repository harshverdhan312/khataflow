import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sync_queue_table.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase> with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<void> enqueue(SyncQueueCompanion entry) {
    return into(syncQueue).insert(entry);
  }

  Future<List<SyncQueueEntity>> getPendingItems({int limit = 50}) {
    return (select(syncQueue)
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<int> incrementAttempt(
    String id, {
    String? error,
    required int attemptedAt,
  }) async {
    final item = await (select(syncQueue)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (item == null) return 0;

    return (update(syncQueue)..where((tbl) => tbl.id.equals(id))).write(
      SyncQueueCompanion(
        attemptCount: Value(item.attemptCount + 1),
        lastAttemptAt: Value(attemptedAt),
        lastError: Value(error),
      ),
    );
  }

  Future<int> deleteItem(String id) {
    return (delete(syncQueue)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<int> deleteItems(List<String> ids) {
    return (delete(syncQueue)..where((tbl) => tbl.id.isIn(ids))).go();
  }

  Future<int> getPendingCount() async {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)..addColumns([count]);
    final result = await query.map((row) => row.read(count)).getSingle();
    return result ?? 0;
  }

  Stream<int> watchPendingCount() {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)..addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }
}

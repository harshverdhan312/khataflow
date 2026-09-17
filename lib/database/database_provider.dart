import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import 'daos/expense_dao.dart';
import 'daos/merchant_dao.dart';
import 'daos/purchase_dao.dart';
import 'daos/settlement_dao.dart';
import 'daos/sync_queue_dao.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() => database.close());
  return database;
});

final merchantDaoProvider = Provider<MerchantDao>((ref) {
  return ref.watch(appDatabaseProvider).merchantDao;
});

final purchaseDaoProvider = Provider<PurchaseDao>((ref) {
  return ref.watch(appDatabaseProvider).purchaseDao;
});

final settlementDaoProvider = Provider<SettlementDao>((ref) {
  return ref.watch(appDatabaseProvider).settlementDao;
});

final syncQueueDaoProvider = Provider<SyncQueueDao>((ref) {
  return ref.watch(appDatabaseProvider).syncQueueDao;
});

final expenseDaoProvider = Provider<ExpenseDao>((ref) {
  return ref.watch(appDatabaseProvider).expenseDao;
});


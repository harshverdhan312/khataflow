import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/database_provider.dart';
import '../../expense/presentation/expense_providers.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_repository_impl.dart';
import '../domain/dashboard_summary.dart';
import '../domain/expense_dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DashboardRepositoryImpl(db);
});

final dashboardSummaryStreamProvider = StreamProvider<DashboardSummary>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.watchDashboardSummary();
});

final expenseDashboardSummaryProvider = Provider<AsyncValue<ExpenseDashboardSummary>>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  return expensesAsync.whenData((expenses) {
    return deriveExpenseDashboardSummary(expenses);
  });
});

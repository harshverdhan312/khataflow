import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/database_provider.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_repository_impl.dart';
import '../domain/dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DashboardRepositoryImpl(db);
});

final dashboardSummaryStreamProvider = StreamProvider<DashboardSummary>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.watchDashboardSummary();
});

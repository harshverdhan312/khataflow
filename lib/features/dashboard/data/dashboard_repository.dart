import '../domain/dashboard_summary.dart';

abstract class DashboardRepository {
  Stream<DashboardSummary> watchDashboardSummary();
  Future<DashboardSummary> getDashboardSummary();
}

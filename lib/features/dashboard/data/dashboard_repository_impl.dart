import '../../../database/app_database.dart';
import '../../merchant/domain/merchant.dart';
import '../../merchant/domain/merchant_category.dart';
import '../domain/dashboard_summary.dart';
import 'dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final AppDatabase _db;

  DashboardRepositoryImpl(this._db);

  @override
  Stream<DashboardSummary> watchDashboardSummary() {
    // Custom query that joins active merchants with their calculated outstanding balance and last active purchase date
    final sql = '''
      SELECT 
        m.id,
        m.name,
        m.category,
        m.phone,
        m.upi_vpa,
        m.created_at,
        m.updated_at,
        m.is_active,
        COALESCE((
          SELECT SUM(p.amount_paise)
          FROM purchases p
          WHERE p.merchant_id = m.id
            AND p.id NOT IN (
              SELECT si.purchase_id
              FROM settlement_items si
              INNER JOIN settlements s ON s.id = si.settlement_id
              WHERE s.status IN ('SUCCESS', 'SETTLED')
            )
        ), 0) AS outstanding_paise,
        (
          SELECT MAX(p.purchase_date)
          FROM purchases p
          WHERE p.merchant_id = m.id
        ) AS last_purchase_date
      FROM merchants m
      WHERE m.is_active = 1
      ORDER BY m.name ASC
    ''';

    return _db.customSelect(
      sql,
      readsFrom: {_db.merchants, _db.purchases, _db.settlements, _db.settlementItems},
    ).watch().map((rows) {
      int totalOutstanding = 0;
      final summaries = <MerchantLedgerSummary>[];

      for (final row in rows) {
        final outstanding = row.read<int>('outstanding_paise');
        totalOutstanding += outstanding;

        final lastPurchaseDateMs = row.readNullable<int>('last_purchase_date');
        final lastActiveAt = lastPurchaseDateMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastPurchaseDateMs)
            : null;

        final merchant = Merchant(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          category: MerchantCategory.fromDbValue(row.read<String>('category')),
          phone: row.readNullable<String>('phone'),
          upiVpa: row.read<String>('upi_vpa'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
          isActive: row.read<bool>('is_active'),
        );

        summaries.add(
          MerchantLedgerSummary(
            merchant: merchant,
            outstandingPaise: outstanding,
            lastActiveAt: lastActiveAt,
          ),
        );
      }

      return DashboardSummary(
        totalOutstandingPaise: totalOutstanding,
        merchantSummaries: summaries,
      );
    });
  }

  @override
  Future<DashboardSummary> getDashboardSummary() async {
    final stream = watchDashboardSummary();
    return stream.first;
  }
}

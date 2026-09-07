import '../../merchant/domain/merchant.dart';

class MerchantLedgerSummary {
  final Merchant merchant;
  final int outstandingPaise;
  final DateTime? lastActiveAt;

  const MerchantLedgerSummary({
    required this.merchant,
    required this.outstandingPaise,
    this.lastActiveAt,
  });
}

class DashboardSummary {
  final int totalOutstandingPaise;
  final List<MerchantLedgerSummary> merchantSummaries;

  const DashboardSummary({
    required this.totalOutstandingPaise,
    required this.merchantSummaries,
  });
}

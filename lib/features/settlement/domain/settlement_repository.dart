import 'settlement.dart';
import 'settlement_status.dart';

abstract class SettlementRepository {
  Future<Settlement> initiateSettlement({
    required String merchantId,
    required List<String> purchaseIds,
  });

  Future<void> updateSettlementStatus({
    required String settlementId,
    required SettlementStatus status,
    String? transactionId,
    String? utr,
  });

  Future<void> markUpiLaunched(String settlementId);

  Future<void> markSettlementSuccess({
    required String settlementId,
    String? transactionId,
    String? utr,
  });

  Future<void> markSettlementFailed({
    required String settlementId,
    required String reason,
  });

  Future<Settlement?> getSettlementById(String settlementId);

  Stream<List<Settlement>> watchSettlementsForMerchant(String merchantId);
}

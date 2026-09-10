import '../../receipt/domain/settlement_receipt.dart';
import 'settlement.dart';
import 'settlement_status.dart';

abstract class SettlementRepository {
  /// Initiates a settlement for the given purchases after verifying they are valid
  /// and not part of an existing unresolved settlement.
  Future<Settlement> initiateSettlement({
    required String merchantId,
    required List<String> purchaseIds,
  });

  /// Transitions settlement state and updates transaction/UTR details.
  Future<void> updateSettlementStatus({
    required String settlementId,
    required SettlementStatus status,
    String? transactionId,
    String? utr,
  });

  /// Marks a settlement as UPI_LAUNCHED.
  Future<void> markUpiLaunched(String settlementId);

  /// Marks a settlement as SETTLED upon manual user confirmation.
  Future<void> markSettlementSettled({
    required String settlementId,
    String? transactionId,
    String? utr,
  });

  /// Marks a settlement as FAILED.
  Future<void> markSettlementFailed({
    required String settlementId,
    required String reason,
  });

  /// Marks a settlement as UNKNOWN.
  Future<void> markSettlementUnknown({
    required String settlementId,
  });

  /// Retrieves a settlement by its unique ID with linked items.
  Future<Settlement?> getSettlementById(String settlementId);

  /// Retrieves a complete receipt for a successfully SETTLED settlement.
  /// Returns null if the settlement does not exist or is not in SETTLED status.
  Future<SettlementReceipt?> getSettlementReceipt(String settlementId);

  /// Retrieves all unresolved settlements (INITIATED, UPI_LAUNCHED, or UNKNOWN), optionally filtered by merchant.
  Future<List<Settlement>> getUnresolvedSettlements({String? merchantId});

  /// Checks if there is currently any unresolved settlement for the merchant.
  Future<bool> hasUnresolvedSettlementForMerchant(String merchantId);

  /// Returns a set/list of purchase IDs currently linked to any unresolved settlement for the merchant.
  Future<List<String>> getUnresolvedPurchaseIds(String merchantId);

  /// Streams all settlements for a merchant ordered chronologically.
  Stream<List<Settlement>> watchSettlementsForMerchant(String merchantId);

  /// Streams all settlements across all merchants ordered chronologically descending.
  Stream<List<Settlement>> watchAllSettlements();

  /// Gets all settlements across all merchants ordered chronologically descending.
  Future<List<Settlement>> getAllSettlements();
}



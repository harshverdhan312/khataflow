import 'purchase.dart';

abstract class LedgerRepository {
  Stream<List<Purchase>> watchPurchases(String merchantId);

  Stream<int> watchOutstandingAmount(String merchantId);

  Stream<int> watchTotalOutstanding();

  Future<List<Purchase>> getPurchases(String merchantId);

  Future<int> getOutstandingAmount(String merchantId);

  Future<int> getTotalOutstanding();

  Future<Purchase> addPurchase(CreatePurchaseInput input);

  Future<List<Purchase>> getUnsettledPurchases(String merchantId);
}

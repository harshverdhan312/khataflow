import 'merchant.dart';

abstract class MerchantRepository {
  Stream<List<Merchant>> watchActiveMerchants();

  Stream<List<Merchant>> watchInactiveMerchants();

  Future<List<Merchant>> getActiveMerchants();

  Future<Merchant?> getMerchantById(String id);

  Future<Merchant> createMerchant(CreateMerchantInput input);

  Future<void> updateMerchant(Merchant merchant);

  Future<void> deactivateMerchant(String merchantId);

  Future<void> reactivateMerchant(String merchantId);
}

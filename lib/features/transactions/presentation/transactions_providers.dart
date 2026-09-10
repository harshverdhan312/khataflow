import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../merchant/domain/merchant.dart';
import '../../merchant/presentation/merchant_providers.dart';
import '../../settlement/domain/settlement.dart';
import '../../settlement/presentation/settlement_providers.dart';

final allSettlementsStreamProvider = StreamProvider<List<Settlement>>((ref) {
  final repository = ref.watch(settlementRepositoryProvider);
  return repository.watchAllSettlements();
});

class EnrichedSettlement {
  final Settlement settlement;
  final Merchant? merchant;

  const EnrichedSettlement({
    required this.settlement,
    this.merchant,
  });
}

final allTransactionsStreamProvider = StreamProvider<List<EnrichedSettlement>>((ref) async* {
  final repository = ref.watch(settlementRepositoryProvider);
  final merchantRepo = ref.watch(merchantRepositoryProvider);

  await for (final settlements in repository.watchAllSettlements()) {
    final enrichedList = <EnrichedSettlement>[];
    for (final s in settlements) {
      final merchant = await merchantRepo.getMerchantById(s.merchantId);
      enrichedList.add(EnrichedSettlement(settlement: s, merchant: merchant));
    }
    yield enrichedList;
  }
});

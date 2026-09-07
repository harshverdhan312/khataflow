import '../../ledger/domain/purchase.dart';
import '../../merchant/domain/merchant.dart';
import '../../settlement/domain/settlement.dart';

class ReceiptStatement {
  final Merchant merchant;
  final Settlement settlement;
  final List<Purchase> settledPurchases;
  final String formattedMessage;

  const ReceiptStatement({
    required this.merchant,
    required this.settlement,
    required this.settledPurchases,
    required this.formattedMessage,
  });
}

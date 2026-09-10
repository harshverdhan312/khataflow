import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/native_receipt_share_service.dart';
import '../../../core/services/receipt_share_service.dart';
import '../../../core/services/settlement_pdf_service.dart';
import '../../../core/services/settlement_pdf_service_impl.dart';
import '../../settlement/presentation/settlement_providers.dart';
import '../domain/settlement_receipt.dart';

final receiptShareServiceProvider = Provider<ReceiptShareService>((ref) {
  return const NativeReceiptShareService();
});

final settlementPdfServiceProvider = Provider<SettlementPdfService>((ref) {
  return const SettlementPdfServiceImpl();
});

final settlementReceiptProvider =
    FutureProvider.family<SettlementReceipt?, String>((ref, settlementId) async {
  final repository = ref.watch(settlementRepositoryProvider);
  return repository.getSettlementReceipt(settlementId);
});



import '../domain/receipt_statement.dart';

abstract class ReceiptRepository {
  Future<ReceiptStatement> generateStatement({
    required String settlementId,
  });
}

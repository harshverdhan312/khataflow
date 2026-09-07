enum UpiLaunchStatus {
  success,
  failed,
  appNotInstalled,
  cancelled,
  unknown,
}

class UpiLaunchResult {
  final UpiLaunchStatus status;
  final String? rawResponse;
  final String? txnId;
  final String? responseCode;
  final String? approvalRefNo;
  final String? statusMessage;

  const UpiLaunchResult({
    required this.status,
    this.rawResponse,
    this.txnId,
    this.responseCode,
    this.approvalRefNo,
    this.statusMessage,
  });
}

abstract class UpiService {
  Future<UpiLaunchResult> launchPayment({
    required String vpa,
    required String merchantName,
    required int amountPaise,
    required String transactionNote,
  });
}

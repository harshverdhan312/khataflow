enum UpiLaunchStatus {
  launched,
  noAppInstalled,
  launchFailed,
  resultAvailable,
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

  bool get isLaunched => status == UpiLaunchStatus.launched;
}

abstract class UpiService {
  /// Builds the standard UPI intent URI using strict integer-based paise-to-rupee conversion.
  Uri buildUpiUri({
    required String vpa,
    required String merchantName,
    required int amountPaise,
    required String transactionNote,
  });

  /// Validates whether the VPA has a standard format.
  bool isValidVpa(String vpa);

  /// Launches the UPI payment intent via the platform's external application handler.
  Future<UpiLaunchResult> launchPayment({
    required String vpa,
    required String merchantName,
    required int amountPaise,
    required String transactionNote,
  });
}


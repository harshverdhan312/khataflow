enum SettlementStatus {
  initiated,
  upiLaunched,
  success,
  failed,
  unknown,
  settled;

  String toDbValue() {
    switch (this) {
      case SettlementStatus.initiated:
        return 'INITIATED';
      case SettlementStatus.upiLaunched:
        return 'UPI_LAUNCHED';
      case SettlementStatus.success:
        return 'SUCCESS';
      case SettlementStatus.failed:
        return 'FAILED';
      case SettlementStatus.unknown:
        return 'UNKNOWN';
      case SettlementStatus.settled:
        return 'SETTLED';
    }
  }

  static SettlementStatus fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'INITIATED':
        return SettlementStatus.initiated;
      case 'UPI_LAUNCHED':
        return SettlementStatus.upiLaunched;
      case 'SUCCESS':
        return SettlementStatus.success;
      case 'FAILED':
        return SettlementStatus.failed;
      case 'UNKNOWN':
        return SettlementStatus.unknown;
      case 'SETTLED':
        return SettlementStatus.settled;
      default:
        return SettlementStatus.unknown;
    }
  }

  bool get isTerminal => this == SettlementStatus.settled || this == SettlementStatus.failed;
  bool get isSuccessful => this == SettlementStatus.settled || this == SettlementStatus.success;
}

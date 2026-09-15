enum SettlementStatus {
  initiated,
  settled,
  failed,
  unknown;

  String toDbValue() {
    switch (this) {
      case SettlementStatus.initiated:
        return 'INITIATED';
      case SettlementStatus.settled:
        return 'SETTLED';
      case SettlementStatus.failed:
        return 'FAILED';
      case SettlementStatus.unknown:
        return 'UNKNOWN';
    }
  }

  static SettlementStatus fromDbValue(String value) {
    switch (value.toUpperCase()) {
      case 'INITIATED':
        return SettlementStatus.initiated;
      case 'UPI_LAUNCHED':
        return SettlementStatus.unknown;
      case 'SETTLED':
      case 'SUCCESS': // Map legacy/transient SUCCESS to SETTLED
        return SettlementStatus.settled;
      case 'FAILED':
        return SettlementStatus.failed;
      case 'UNKNOWN':
        return SettlementStatus.unknown;
      default:
        return SettlementStatus.unknown;
    }
  }

  bool get isTerminal => this == SettlementStatus.settled || this == SettlementStatus.failed;
  bool get isSettled => this == SettlementStatus.settled;
  bool get isUnresolved => this == SettlementStatus.initiated || this == SettlementStatus.unknown;
}


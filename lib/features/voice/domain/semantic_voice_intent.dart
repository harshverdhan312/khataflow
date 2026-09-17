/// Standard intent categories supported by AI voice semantic interpretation.
enum SemanticVoiceIntent {
  /// Intention to add a purchase/credit item to a merchant's ledger.
  addPurchase,

  /// Intention to record a personal categorized expense.
  addExpense,

  /// Intention to settle a merchant's outstanding ledger balance.
  settleMerchant,

  /// Intention to register a new merchant ledger.
  createMerchant;

  /// String code identifier corresponding to the intent family.
  String get code {
    switch (this) {
      case SemanticVoiceIntent.addPurchase:
        return 'ADD_PURCHASE';
      case SemanticVoiceIntent.addExpense:
        return 'ADD_EXPENSE';
      case SemanticVoiceIntent.settleMerchant:
        return 'SETTLE_MERCHANT';
      case SemanticVoiceIntent.createMerchant:
        return 'CREATE_MERCHANT';
    }
  }

  /// Parses a string code (case-insensitive) into a [SemanticVoiceIntent], returning null if unrecognized.
  static SemanticVoiceIntent? tryFromCode(String code) {
    switch (code.toUpperCase().trim()) {
      case 'ADD_PURCHASE':
        return SemanticVoiceIntent.addPurchase;
      case 'ADD_EXPENSE':
        return SemanticVoiceIntent.addExpense;
      case 'SETTLE_MERCHANT':
        return SemanticVoiceIntent.settleMerchant;
      case 'CREATE_MERCHANT':
        return SemanticVoiceIntent.createMerchant;
      default:
        return null;
    }
  }
}

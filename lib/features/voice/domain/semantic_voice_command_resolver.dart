import 'package:flutter/foundation.dart';
import '../../../core/utils/validators.dart';
import '../../expense/domain/expense_category.dart';
import '../../merchant/domain/merchant.dart';
import '../../merchant/domain/merchant_category.dart';
import 'deterministic_category_resolver.dart';
import 'deterministic_date_parser.dart';
import 'deterministic_money_parser.dart';
import 'merchant_resolver.dart';
import 'semantic_voice_intent.dart';
import 'semantic_voice_interpretation.dart';
import 'voice_command.dart';

/// Sealed result representing the outcome of deterministic re-validation and entity resolution.
@immutable
sealed class SemanticVoiceResolutionResult {
  const SemanticVoiceResolutionResult();

  bool get isResolved => this is SemanticVoiceResolved;
  bool get isAmbiguous => this is SemanticVoiceAmbiguous;
  bool get isFailure => this is SemanticVoiceResolutionFailure;
}

/// Successfully resolved into an executable [VoiceCommand] with all financial & entity values
/// validated and reconstructed deterministically.
@immutable
class SemanticVoiceResolved extends SemanticVoiceResolutionResult {
  final VoiceCommand command;
  final Merchant? resolvedMerchant;

  const SemanticVoiceResolved({
    required this.command,
    this.resolvedMerchant,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVoiceResolved &&
          runtimeType == other.runtimeType &&
          command == other.command &&
          resolvedMerchant == other.resolvedMerchant;

  @override
  int get hashCode => Object.hash(command, resolvedMerchant);

  @override
  String toString() =>
      'SemanticVoiceResolved(command: $command, resolvedMerchant: ${resolvedMerchant?.name})';
}

/// Merchant resolution matched multiple active stores; user disambiguation is required.
///
/// NOTE: Intentionally does NOT store an executable [VoiceCommand].
/// Re-validation occurs freshly after candidate selection.
@immutable
class SemanticVoiceAmbiguous extends SemanticVoiceResolutionResult {
  final String query;
  final List<Merchant> candidateMerchants;
  final SemanticVoiceInterpretation interpretation;

  const SemanticVoiceAmbiguous({
    required this.query,
    required this.candidateMerchants,
    required this.interpretation,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVoiceAmbiguous &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          listEquals(candidateMerchants, other.candidateMerchants) &&
          interpretation == other.interpretation;

  @override
  int get hashCode =>
      Object.hash(query, Object.hashAll(candidateMerchants), interpretation);

  @override
  String toString() =>
      'SemanticVoiceAmbiguous(query: "$query", candidates: ${candidateMerchants.map((c) => c.name).toList()})';
}

/// Resolution or validation failed deterministically.
@immutable
class SemanticVoiceResolutionFailure extends SemanticVoiceResolutionResult {
  final String reason;
  final String? rawTranscript;

  const SemanticVoiceResolutionFailure({
    required this.reason,
    this.rawTranscript,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVoiceResolutionFailure &&
          runtimeType == other.runtimeType &&
          reason == other.reason &&
          rawTranscript == other.rawTranscript;

  @override
  int get hashCode => Object.hash(reason, rawTranscript);

  @override
  String toString() =>
      'SemanticVoiceResolutionFailure(reason: "$reason", rawTranscript: "$rawTranscript")';
}

/// Pure deterministic domain resolver that bridges untrusted [SemanticVoiceInterpretation]
/// to executable [VoiceCommand] objects.
///
/// Safety Guarantees:
/// 1. AI output is NEVER executed directly.
/// 2. All monetary values are parsed strictly via [DeterministicMoneyParser] into integer paise.
/// 3. All merchant queries are resolved strictly via [MerchantResolver] against live [Merchant] records.
/// 4. All categories are validated strictly via [DeterministicCategoryResolver].
/// 5. All dates are parsed strictly via [DeterministicDateParser].
/// 6. ZERO database mutations, sync records, or network/AI calls occur in this resolver.
class SemanticVoiceCommandResolver {
  final MerchantResolver merchantResolver;
  final DeterministicMoneyParser moneyParser;
  final DeterministicCategoryResolver categoryResolver;
  final DeterministicDateParser dateParser;

  const SemanticVoiceCommandResolver({
    this.merchantResolver = const MerchantResolver(),
    this.moneyParser = const DeterministicMoneyParser(),
    this.categoryResolver = const DeterministicCategoryResolver(),
    this.dateParser = const DeterministicDateParser(),
  });

  /// Resolves [interpretation] against [activeMerchants].
  SemanticVoiceResolutionResult resolve({
    required SemanticVoiceInterpretation interpretation,
    required List<Merchant> activeMerchants,
    DateTime? referenceDate,
  }) {
    switch (interpretation.intent) {
      case SemanticVoiceIntent.addPurchase:
        return _resolveAddPurchase(interpretation, activeMerchants, referenceDate);

      case SemanticVoiceIntent.addExpense:
        return _resolveAddExpense(interpretation, referenceDate);

      case SemanticVoiceIntent.settleMerchant:
        return _resolveSettleMerchant(interpretation, activeMerchants);

      case SemanticVoiceIntent.createMerchant:
        return _resolveCreateMerchant(interpretation, activeMerchants);
    }
  }

  /// Re-resolves an ambiguous command after the user explicitly selects a [selectedMerchant].
  ///
  /// Protects against stale entity resolution by validating against current [activeMerchants].
  SemanticVoiceResolutionResult resolveWithSelectedMerchant({
    required SemanticVoiceInterpretation interpretation,
    required Merchant selectedMerchant,
    required List<Merchant> activeMerchants,
    DateTime? referenceDate,
  }) {
    // 1. Verify selected merchant is still active in current state
    final isStillActive = activeMerchants.any((m) => m.id == selectedMerchant.id && m.isActive);
    if (!isStillActive) {
      return SemanticVoiceResolutionFailure(
        reason: 'Selected merchant "${selectedMerchant.name}" is no longer active.',
        rawTranscript: interpretation.rawTranscript,
      );
    }

    switch (interpretation.intent) {
      case SemanticVoiceIntent.addPurchase:
        return _buildPurchaseCommandForMerchant(
          interpretation: interpretation,
          merchant: selectedMerchant,
          referenceDate: referenceDate,
        );

      case SemanticVoiceIntent.settleMerchant:
        return _buildSettlementCommandForMerchant(
          interpretation: interpretation,
          merchant: selectedMerchant,
        );

      case SemanticVoiceIntent.createMerchant:
        // Selecting an existing merchant when intending to create one is a duplicate error
        return SemanticVoiceResolutionFailure(
          reason: 'Merchant "${selectedMerchant.name}" already exists.',
          rawTranscript: interpretation.rawTranscript,
        );

      case SemanticVoiceIntent.addExpense:
        return _resolveAddExpense(interpretation, referenceDate);
    }
  }

  // ==========================================
  // PURCHASE RESOLUTION
  // ==========================================

  SemanticVoiceResolutionResult _resolveAddPurchase(
    SemanticVoiceInterpretation interpretation,
    List<Merchant> activeMerchants,
    DateTime? referenceDate,
  ) {
    final rawMerchant = interpretation.merchantReference?.trim() ?? '';
    if (rawMerchant.isEmpty) {
      return SemanticVoiceResolutionFailure(
        reason: 'No merchant was specified for purchase.',
        rawTranscript: interpretation.rawTranscript,
      );
    }

    final match = merchantResolver.resolve(
      query: rawMerchant,
      activeMerchants: activeMerchants,
    );

    switch (match) {
      case ExactMerchantMatch(:final merchant):
        return _buildPurchaseCommandForMerchant(
          interpretation: interpretation,
          merchant: merchant,
          referenceDate: referenceDate,
        );

      case AmbiguousMerchantMatch(:final candidates, :final query):
        return SemanticVoiceAmbiguous(
          query: query,
          candidateMerchants: candidates,
          interpretation: interpretation,
        );

      case NoMerchantMatch(:final query):
        return SemanticVoiceResolutionFailure(
          reason: 'Merchant "$query" not found in active stores.',
          rawTranscript: interpretation.rawTranscript,
        );
    }
  }

  SemanticVoiceResolutionResult _buildPurchaseCommandForMerchant({
    required SemanticVoiceInterpretation interpretation,
    required Merchant merchant,
    DateTime? referenceDate,
  }) {
    // 1. Money validation
    final rawAmount = interpretation.amountText?.trim() ?? '';
    if (rawAmount.isEmpty) {
      return SemanticVoiceResolutionFailure(
        reason: 'Purchase amount is missing.',
        rawTranscript: interpretation.rawTranscript,
      );
    }

    final amountPaise = moneyParser.parseAmountToPaise(rawAmount);
    if (amountPaise == null || amountPaise <= 0) {
      return SemanticVoiceResolutionFailure(
        reason: 'Could not parse a valid purchase amount from "$rawAmount".',
        rawTranscript: interpretation.rawTranscript,
      );
    }

    // 2. Date validation (if dateText provided)
    if (interpretation.dateText != null && interpretation.dateText!.trim().isNotEmpty) {
      final parsedDate = dateParser.parseDate(
        interpretation.dateText!,
        referenceDate: referenceDate,
      );
      if (parsedDate == null) {
        return SemanticVoiceResolutionFailure(
          reason: 'Could not parse date "${interpretation.dateText}".',
          rawTranscript: interpretation.rawTranscript,
        );
      }
    }

    // 3. Item name cleaning
    var itemName = interpretation.item?.trim();
    if (itemName == null || itemName.isEmpty) {
      itemName = interpretation.note?.trim();
    }
    if (itemName == null || itemName.isEmpty) {
      itemName = 'Purchase';
    } else {
      itemName = _cleanItemName(itemName);
      if (itemName.isEmpty) {
        itemName = 'Purchase';
      }
    }

    final command = AddPurchaseCommand(
      merchantName: merchant.name,
      items: [
        VoicePurchaseItem(
          name: itemName,
          amountPaise: amountPaise,
        ),
      ],
      totalAmountPaise: amountPaise,
    );

    return SemanticVoiceResolved(
      command: command,
      resolvedMerchant: merchant,
    );
  }

  // ==========================================
  // EXPENSE RESOLUTION
  // ==========================================

  SemanticVoiceResolutionResult _resolveAddExpense(
    SemanticVoiceInterpretation interpretation,
    DateTime? referenceDate,
  ) {
    // 1. Money validation
    final rawAmount = interpretation.amountText?.trim() ?? '';
    if (rawAmount.isEmpty) {
      return SemanticVoiceResolutionFailure(
        reason: 'Expense amount is missing.',
        rawTranscript: interpretation.rawTranscript,
      );
    }

    final amountPaise = moneyParser.parseAmountToPaise(rawAmount);
    if (amountPaise == null || amountPaise <= 0) {
      return SemanticVoiceResolutionFailure(
        reason: 'Could not parse a valid expense amount from "$rawAmount".',
        rawTranscript: interpretation.rawTranscript,
      );
    }

    // 2. Category validation
    ExpenseCategory? category;
    final rawCategory = interpretation.categoryReference?.trim();
    if (rawCategory != null && rawCategory.isNotEmpty) {
      category = categoryResolver.resolveExpenseCategory(rawCategory);
      if (category == null) {
        return SemanticVoiceResolutionFailure(
          reason: 'Invalid expense category "$rawCategory".',
          rawTranscript: interpretation.rawTranscript,
        );
      }
    }

    // 3. Date validation
    DateTime expenseDate = referenceDate ?? DateTime.now();
    final rawDate = interpretation.dateText?.trim();
    if (rawDate != null && rawDate.isNotEmpty) {
      final parsedDate = dateParser.parseDate(rawDate, referenceDate: referenceDate);
      if (parsedDate == null) {
        return SemanticVoiceResolutionFailure(
          reason: 'Could not parse date "$rawDate".',
          rawTranscript: interpretation.rawTranscript,
        );
      }
      expenseDate = parsedDate;
    }

    // 4. Note validation & sanitization
    var note = interpretation.note?.trim();
    if (note != null && note.isNotEmpty) {
      if (note.length > 200) {
        note = note.substring(0, 200).trim();
      }
    } else {
      note = null;
    }

    final command = AddExpenseCommand(
      amountPaise: amountPaise,
      category: category,
      note: note,
      expenseDate: expenseDate,
    );

    return SemanticVoiceResolved(command: command);
  }

  // ==========================================
  // SETTLEMENT RESOLUTION
  // ==========================================

  SemanticVoiceResolutionResult _resolveSettleMerchant(
    SemanticVoiceInterpretation interpretation,
    List<Merchant> activeMerchants,
  ) {
    final rawMerchant = interpretation.merchantReference?.trim() ?? '';
    if (rawMerchant.isEmpty) {
      return SemanticVoiceResolutionFailure(
        reason: 'No merchant was specified for settlement.',
        rawTranscript: interpretation.rawTranscript,
      );
    }

    final match = merchantResolver.resolve(
      query: rawMerchant,
      activeMerchants: activeMerchants,
    );

    switch (match) {
      case ExactMerchantMatch(:final merchant):
        return _buildSettlementCommandForMerchant(
          interpretation: interpretation,
          merchant: merchant,
        );

      case AmbiguousMerchantMatch(:final candidates, :final query):
        return SemanticVoiceAmbiguous(
          query: query,
          candidateMerchants: candidates,
          interpretation: interpretation,
        );

      case NoMerchantMatch(:final query):
        return SemanticVoiceResolutionFailure(
          reason: 'Merchant "$query" not found in active stores.',
          rawTranscript: interpretation.rawTranscript,
        );
    }
  }

  SemanticVoiceResolutionResult _buildSettlementCommandForMerchant({
    required SemanticVoiceInterpretation interpretation,
    required Merchant merchant,
  }) {
    final rawAmount = interpretation.amountText?.trim();

    if (rawAmount != null && rawAmount.isNotEmpty) {
      final amountPaise = moneyParser.parseAmountToPaise(rawAmount);
      if (amountPaise == null || amountPaise <= 0) {
        return SemanticVoiceResolutionFailure(
          reason: 'Could not parse settlement amount from "$rawAmount".',
          rawTranscript: interpretation.rawTranscript,
        );
      }

      final command = RecordSettlementCommand(
        merchantName: merchant.name,
        amountPaise: amountPaise,
        paymentReference: interpretation.paymentReference?.trim(),
      );

      return SemanticVoiceResolved(
        command: command,
        resolvedMerchant: merchant,
      );
    } else {
      final command = SettleMerchantCommand(
        merchantName: merchant.name,
      );

      return SemanticVoiceResolved(
        command: command,
        resolvedMerchant: merchant,
      );
    }
  }

  // ==========================================
  // CREATE MERCHANT RESOLUTION
  // ==========================================

  SemanticVoiceResolutionResult _resolveCreateMerchant(
    SemanticVoiceInterpretation interpretation,
    List<Merchant> activeMerchants,
  ) {
    final rawName = interpretation.merchantReference?.trim() ?? '';
    if (rawName.isEmpty) {
      return SemanticVoiceResolutionFailure(
        reason: 'Merchant name cannot be empty.',
        rawTranscript: interpretation.rawTranscript,
      );
    }

    final cleanName = _cleanMerchantName(rawName);
    if (cleanName.isEmpty) {
      return SemanticVoiceResolutionFailure(
        reason: 'Invalid merchant name "$rawName".',
        rawTranscript: interpretation.rawTranscript,
      );
    }

    // Check for duplicate or ambiguous active store match
    final match = merchantResolver.resolve(
      query: cleanName,
      activeMerchants: activeMerchants,
    );

    switch (match) {
      case ExactMerchantMatch(:final merchant):
        return SemanticVoiceResolutionFailure(
          reason: 'Merchant "${merchant.name}" already exists.',
          rawTranscript: interpretation.rawTranscript,
        );

      case AmbiguousMerchantMatch(:final candidates, :final query):
        return SemanticVoiceAmbiguous(
          query: query,
          candidateMerchants: candidates,
          interpretation: interpretation,
        );

      case NoMerchantMatch():
        break;
    }

    // Category validation
    MerchantCategory? category;
    final rawCategory = interpretation.categoryReference?.trim();
    if (rawCategory != null && rawCategory.isNotEmpty) {
      category = categoryResolver.resolveMerchantCategory(rawCategory);
      if (category == null) {
        return SemanticVoiceResolutionFailure(
          reason: 'Invalid merchant category "$rawCategory".',
          rawTranscript: interpretation.rawTranscript,
        );
      }
    }

    // UPI VPA validation
    String? upiVpa;
    final rawVpa = interpretation.paymentReference?.trim();
    if (rawVpa != null && rawVpa.isNotEmpty) {
      // Check if rawVpa contains a VPA pattern or starts with upi/vpa
      var vpa = rawVpa.replaceAll(RegExp(r'\s*@\s*'), '@').replaceAll(RegExp(r'\s+'), '');
      if (vpa.startsWith('upi:') || vpa.startsWith('vpa:')) {
        vpa = vpa.substring(4);
      }
      final vpaError = Validators.validateUpiVpa(vpa, isOptional: false);
      if (vpaError != null) {
        return SemanticVoiceResolutionFailure(
          reason: 'Invalid UPI ID "$rawVpa".',
          rawTranscript: interpretation.rawTranscript,
        );
      }
      upiVpa = vpa;
    }

    final command = CreateMerchantCommand(
      merchantName: cleanName,
      category: category,
      upiVpa: upiVpa,
    );

    return SemanticVoiceResolved(command: command);
  }

  // ==========================================
  // HELPERS
  // ==========================================

  String _cleanMerchantName(String raw) {
    var name = raw.trim();
    name = name.replaceAll(RegExp(r'^(?:from|to|with)\s+', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\s+(?:ki\s+dukaan|ke\s+yahan)\b', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[^\w\s\.]'), '').trim();
    if (name.isEmpty) return '';

    return name.split(' ').where((w) => w.isNotEmpty).map((word) {
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1) : '');
    }).join(' ');
  }

  String _cleanItemName(String raw) {
    var name = raw.trim();
    name = name.replaceAll(RegExp(r'\b(?:ka|ki|ke|aur|and|rupaye|rupees|rs)\b', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return '';

    return name[0].toUpperCase() + (name.length > 1 ? name.substring(1) : '');
  }
}

import 'package:flutter/foundation.dart';
import 'semantic_voice_intent.dart';
import 'voice_understanding_source.dart';

/// Immutable domain model representing a semantic interpretation of spoken text.
///
/// Contains purely semantic and raw textual extractions produced by AI or semantic fallbacks.
/// Crucially, this model does NOT contain authoritative financial data (such as integer paise).
/// All monetary strings remain raw text (`amountText`) to be parsed authoritatively by deterministic money parsers.
@immutable
class SemanticVoiceInterpretation {
  /// The recognized command intention family.
  final SemanticVoiceIntent intent;

  /// The raw extracted merchant name or identifier reference (if present in speech).
  final String? merchantReference;

  /// The item or product name (e.g. for purchases).
  final String? item;

  /// The raw category reference or expression (e.g. "food", "transport", "grocery store").
  final String? categoryReference;

  /// The raw monetary expression extracted from speech (e.g. "500", "twenty five rupees", "1.5k").
  /// Must NOT be an integer paise amount; deterministic money parsers remain authoritative.
  final String? amountText;

  /// The raw date or time reference from speech (e.g. "today", "yesterday", "5th september").
  final String? dateText;

  /// Optional contextual note or description.
  final String? note;

  /// Optional payment mode or transaction reference (e.g. "via UPI", "cash", "Google Pay").
  final String? paymentReference;

  /// The source mechanism through which this interpretation was obtained.
  final VoiceUnderstandingSource source;

  /// The original spoken transcript from which this semantic interpretation was extracted.
  final String? rawTranscript;

  const SemanticVoiceInterpretation({
    required this.intent,
    this.merchantReference,
    this.item,
    this.categoryReference,
    this.amountText,
    this.dateText,
    this.note,
    this.paymentReference,
    this.source = VoiceUnderstandingSource.aiFallback,
    this.rawTranscript,
  });

  /// Factory constructor for [SemanticVoiceIntent.addPurchase] interpretation.
  factory SemanticVoiceInterpretation.addPurchase({
    required String merchantReference,
    String? item,
    required String amountText,
    String? dateText,
    String? note,
    VoiceUnderstandingSource source = VoiceUnderstandingSource.aiFallback,
    String? rawTranscript,
  }) {
    return SemanticVoiceInterpretation(
      intent: SemanticVoiceIntent.addPurchase,
      merchantReference: merchantReference,
      item: item,
      amountText: amountText,
      dateText: dateText,
      note: note,
      source: source,
      rawTranscript: rawTranscript,
    );
  }

  /// Factory constructor for [SemanticVoiceIntent.addExpense] interpretation.
  factory SemanticVoiceInterpretation.addExpense({
    required String amountText,
    String? categoryReference,
    String? note,
    String? dateText,
    VoiceUnderstandingSource source = VoiceUnderstandingSource.aiFallback,
    String? rawTranscript,
  }) {
    return SemanticVoiceInterpretation(
      intent: SemanticVoiceIntent.addExpense,
      amountText: amountText,
      categoryReference: categoryReference,
      note: note,
      dateText: dateText,
      source: source,
      rawTranscript: rawTranscript,
    );
  }

  /// Factory constructor for [SemanticVoiceIntent.settleMerchant] interpretation.
  factory SemanticVoiceInterpretation.settleMerchant({
    required String merchantReference,
    String? amountText,
    String? paymentReference,
    String? dateText,
    String? note,
    VoiceUnderstandingSource source = VoiceUnderstandingSource.aiFallback,
    String? rawTranscript,
  }) {
    return SemanticVoiceInterpretation(
      intent: SemanticVoiceIntent.settleMerchant,
      merchantReference: merchantReference,
      amountText: amountText,
      paymentReference: paymentReference,
      dateText: dateText,
      note: note,
      source: source,
      rawTranscript: rawTranscript,
    );
  }

  /// Factory constructor for [SemanticVoiceIntent.createMerchant] interpretation.
  factory SemanticVoiceInterpretation.createMerchant({
    required String merchantReference,
    String? categoryReference,
    String? note,
    VoiceUnderstandingSource source = VoiceUnderstandingSource.aiFallback,
    String? rawTranscript,
  }) {
    return SemanticVoiceInterpretation(
      intent: SemanticVoiceIntent.createMerchant,
      merchantReference: merchantReference,
      categoryReference: categoryReference,
      note: note,
      source: source,
      rawTranscript: rawTranscript,
    );
  }

  SemanticVoiceInterpretation copyWith({
    SemanticVoiceIntent? intent,
    String? merchantReference,
    String? item,
    String? categoryReference,
    String? amountText,
    String? dateText,
    String? note,
    String? paymentReference,
    VoiceUnderstandingSource? source,
    String? rawTranscript,
  }) {
    return SemanticVoiceInterpretation(
      intent: intent ?? this.intent,
      merchantReference: merchantReference ?? this.merchantReference,
      item: item ?? this.item,
      categoryReference: categoryReference ?? this.categoryReference,
      amountText: amountText ?? this.amountText,
      dateText: dateText ?? this.dateText,
      note: note ?? this.note,
      paymentReference: paymentReference ?? this.paymentReference,
      source: source ?? this.source,
      rawTranscript: rawTranscript ?? this.rawTranscript,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVoiceInterpretation &&
          runtimeType == other.runtimeType &&
          intent == other.intent &&
          merchantReference == other.merchantReference &&
          item == other.item &&
          categoryReference == other.categoryReference &&
          amountText == other.amountText &&
          dateText == other.dateText &&
          note == other.note &&
          paymentReference == other.paymentReference &&
          source == other.source &&
          rawTranscript == other.rawTranscript;

  @override
  int get hashCode => Object.hash(
        intent,
        merchantReference,
        item,
        categoryReference,
        amountText,
        dateText,
        note,
        paymentReference,
        source,
        rawTranscript,
      );

  @override
  String toString() =>
      'SemanticVoiceInterpretation(intent: $intent, merchant: $merchantReference, item: $item, category: $categoryReference, amountText: "$amountText", date: $dateText, note: $note, paymentRef: $paymentReference, source: $source)';
}

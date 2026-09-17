import 'dart:convert';

import '../../domain/semantic_voice_intent.dart';
import '../../domain/semantic_voice_interpretation.dart';
import '../../domain/semantic_voice_result.dart';
import '../../domain/voice_understanding_source.dart';

/// Strict parser and validator for AI-generated semantic voice command responses.
///
/// Converts an untrusted raw JSON response into a validated [SemanticVoiceInterpretation].
/// Rejects malformed, incomplete, unsafe, or semantically invalid responses without guessing or fuzzy repairing.
class AiVoiceResponseParser {
  static const int maxMerchantRefLength = 120;
  static const int maxItemLength = 200;
  static const int maxCategoryRefLength = 100;
  static const int maxAmountTextLength = 100;
  static const int maxDateTextLength = 100;
  static const int maxNoteLength = 200;
  static const int maxPaymentRefLength = 120;
  static const int maxRawTranscriptLength = 2000;

  const AiVoiceResponseParser();

  /// Parses [rawResponse] into a [SemanticVoiceResult] paired with the caller's [rawTranscript].
  SemanticVoiceResult parse(
    String rawResponse, {
    required String rawTranscript,
  }) {
    // 1. Validate caller transcript bounds
    if (rawTranscript.length > maxRawTranscriptLength) {
      return SemanticVoiceUnresolved(
        rawTranscript: rawTranscript,
        failureReason: 'Raw transcript exceeds maximum length limit of $maxRawTranscriptLength characters.',
      );
    }

    // 2. Reject empty or blank response
    final trimmedResponse = rawResponse.trim();
    if (trimmedResponse.isEmpty) {
      return SemanticVoiceUnresolved(
        rawTranscript: rawTranscript,
        failureReason: 'AI response is empty or blank.',
      );
    }

    // 3. Clean optional surrounding Markdown JSON code fence
    final jsonTextOrError = _stripMarkdownFence(trimmedResponse);
    if (jsonTextOrError.isError) {
      return SemanticVoiceUnresolved(
        rawTranscript: rawTranscript,
        failureReason: jsonTextOrError.error!,
      );
    }

    final jsonText = jsonTextOrError.text!;

    // 4. Decode JSON safely
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (e) {
      return SemanticVoiceUnresolved(
        rawTranscript: rawTranscript,
        failureReason: 'Failed to decode AI response as valid JSON.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return SemanticVoiceUnresolved(
        rawTranscript: rawTranscript,
        failureReason: 'Root JSON value must be a JSON object.',
      );
    }

    final json = decoded;

    // 5. Validate Intent field presence and type
    if (!json.containsKey('intent') || json['intent'] == null) {
      return SemanticVoiceUnresolved(
        rawTranscript: rawTranscript,
        failureReason: 'Missing or null "intent" field in AI response.',
      );
    }

    if (json['intent'] is! String) {
      return SemanticVoiceUnresolved(
        rawTranscript: rawTranscript,
        failureReason: '"intent" field must be a string.',
      );
    }

    final rawIntentCode = (json['intent'] as String).trim();
    final intent = SemanticVoiceIntent.tryFromCode(rawIntentCode);
    if (intent == null) {
      return SemanticVoiceUnresolved(
        rawTranscript: rawTranscript,
        failureReason: 'Unknown or unsupported intent code: "$rawIntentCode".',
      );
    }

    // 6. Validate types of all semantic fields
    final typeCheckError = _validateFieldTypes(json);
    if (typeCheckError != null) {
      return SemanticVoiceUnresolved(
        rawTranscript: rawTranscript,
        failureReason: typeCheckError,
      );
    }

    // 7. Normalize strings (trim & convert empty to null)
    final merchantRef = _normalizeString(json['merchant_reference']);
    final item = _normalizeString(json['item']);
    final categoryRef = _normalizeString(json['category_reference']);
    final amountText = _normalizeString(json['amount_text']);
    final dateText = _normalizeString(json['date_text']);
    final note = _normalizeString(json['note']);
    final paymentRef = _normalizeString(json['payment_reference']);

    // 8. Validate maximum field lengths
    final lengthCheckError = _validateFieldLengths(
      merchantRef: merchantRef,
      item: item,
      categoryRef: categoryRef,
      amountText: amountText,
      dateText: dateText,
      note: note,
      paymentRef: paymentRef,
    );
    if (lengthCheckError != null) {
      return SemanticVoiceUnresolved(
        rawTranscript: rawTranscript,
        failureReason: lengthCheckError,
      );
    }

    // 9. Intent-specific structural validation
    final intentValidationError = _validateIntentStructure(
      intent: intent,
      merchantRef: merchantRef,
      item: item,
      categoryRef: categoryRef,
      amountText: amountText,
      dateText: dateText,
      note: note,
      paymentRef: paymentRef,
    );
    if (intentValidationError != null) {
      return SemanticVoiceUnresolved(
        rawTranscript: rawTranscript,
        failureReason: intentValidationError,
      );
    }

    // 10. Construct validated domain interpretation with immutable source guarantee
    final interpretation = SemanticVoiceInterpretation(
      intent: intent,
      merchantReference: merchantRef,
      item: item,
      categoryReference: categoryRef,
      amountText: amountText,
      dateText: dateText,
      note: note,
      paymentReference: paymentRef,
      source: VoiceUnderstandingSource.aiFallback,
      rawTranscript: rawTranscript,
    );

    return SemanticVoiceSuccess(interpretation);
  }

  /// Safely strips a single surrounding markdown code fence if present.
  _FenceResult _stripMarkdownFence(String text) {
    if (!text.startsWith('```')) {
      // Ensure there are no backticks elsewhere if not fenced
      if (!text.startsWith('{') || !text.endsWith('}')) {
        return _FenceResult.error('Response must be a well-formed JSON object without surrounding prose.');
      }
      return _FenceResult.ok(text);
    }

    final firstNewline = text.indexOf('\n');
    if (firstNewline == -1 || !text.endsWith('```')) {
      return _FenceResult.error('Malformed markdown code fence structure.');
    }

    final header = text.substring(0, firstNewline).trim().toLowerCase();
    if (header != '```json' && header != '```') {
      return _FenceResult.error('Unsupported code fence header: "$header".');
    }

    final inner = text.substring(firstNewline + 1, text.length - 3).trim();
    if (!inner.startsWith('{') || !inner.endsWith('}')) {
      return _FenceResult.error('Enclosed code fence content is not a JSON object.');
    }

    return _FenceResult.ok(inner);
  }

  /// Verifies that all expected semantic fields are either null or of type [String].
  String? _validateFieldTypes(Map<String, dynamic> json) {
    const stringKeys = [
      'merchant_reference',
      'item',
      'category_reference',
      'amount_text',
      'date_text',
      'note',
      'payment_reference',
    ];

    for (final key in stringKeys) {
      if (json.containsKey(key) && json[key] != null && json[key] is! String) {
        return 'Field "$key" must be a string or null (found ${json[key].runtimeType}).';
      }
    }

    return null;
  }

  /// Normalizes a nullable string by trimming whitespace and mapping empty-after-trim to null.
  String? _normalizeString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Enforces maximum character bounds for all semantic strings.
  String? _validateFieldLengths({
    required String? merchantRef,
    required String? item,
    required String? categoryRef,
    required String? amountText,
    required String? dateText,
    required String? note,
    required String? paymentRef,
  }) {
    if (merchantRef != null && merchantRef.length > maxMerchantRefLength) {
      return 'merchant_reference exceeds limit of $maxMerchantRefLength characters.';
    }
    if (item != null && item.length > maxItemLength) {
      return 'item exceeds limit of $maxItemLength characters.';
    }
    if (categoryRef != null && categoryRef.length > maxCategoryRefLength) {
      return 'category_reference exceeds limit of $maxCategoryRefLength characters.';
    }
    if (amountText != null && amountText.length > maxAmountTextLength) {
      return 'amount_text exceeds limit of $maxAmountTextLength characters.';
    }
    if (dateText != null && dateText.length > maxDateTextLength) {
      return 'date_text exceeds limit of $maxDateTextLength characters.';
    }
    if (note != null && note.length > maxNoteLength) {
      return 'note exceeds limit of $maxNoteLength characters.';
    }
    if (paymentRef != null && paymentRef.length > maxPaymentRefLength) {
      return 'payment_reference exceeds limit of $maxPaymentRefLength characters.';
    }
    return null;
  }

  /// Validates required and irrelevant fields based on the specific [SemanticVoiceIntent].
  String? _validateIntentStructure({
    required SemanticVoiceIntent intent,
    required String? merchantRef,
    required String? item,
    required String? categoryRef,
    required String? amountText,
    required String? dateText,
    required String? note,
    required String? paymentRef,
  }) {
    switch (intent) {
      case SemanticVoiceIntent.addPurchase:
        if (merchantRef == null) return 'ADD_PURCHASE requires "merchant_reference".';
        if (item == null) return 'ADD_PURCHASE requires "item".';
        if (amountText == null) return 'ADD_PURCHASE requires "amount_text".';
        if (categoryRef != null) return 'ADD_PURCHASE cannot contain "category_reference".';
        if (paymentRef != null) return 'ADD_PURCHASE cannot contain "payment_reference".';
        return null;

      case SemanticVoiceIntent.addExpense:
        if (amountText == null) return 'ADD_EXPENSE requires "amount_text".';
        if (merchantRef != null) return 'ADD_EXPENSE cannot contain "merchant_reference".';
        if (item != null) return 'ADD_EXPENSE cannot contain "item".';
        if (paymentRef != null) return 'ADD_EXPENSE cannot contain "payment_reference".';
        return null;

      case SemanticVoiceIntent.settleMerchant:
        if (merchantRef == null) return 'SETTLE_MERCHANT requires "merchant_reference".';
        if (item != null) return 'SETTLE_MERCHANT cannot contain "item".';
        if (categoryRef != null) return 'SETTLE_MERCHANT cannot contain "category_reference".';
        return null;

      case SemanticVoiceIntent.createMerchant:
        if (merchantRef == null) return 'CREATE_MERCHANT requires "merchant_reference".';
        if (item != null) return 'CREATE_MERCHANT cannot contain "item".';
        if (amountText != null) return 'CREATE_MERCHANT cannot contain "amount_text".';
        if (dateText != null) return 'CREATE_MERCHANT cannot contain "date_text".';
        return null;
    }
  }
}

class _FenceResult {
  final String? text;
  final String? error;

  const _FenceResult.ok(this.text) : error = null;
  const _FenceResult.error(this.error) : text = null;

  bool get isError => error != null;
}

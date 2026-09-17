import 'dart:convert';

import '../../domain/ai_voice_command_request.dart';
import '../../domain/ai_voice_command_provider.dart';

/// Deterministic mock implementation of [AiVoiceCommandProvider] for development and testing.
///
/// Operates completely offline without HTTP, network requests, or API credentials.
class MockAiVoiceCommandProvider implements AiVoiceCommandProvider {
  final String? customRawResponse;
  final String Function(AiVoiceCommandRequest)? responseHandler;

  const MockAiVoiceCommandProvider({
    this.customRawResponse,
    this.responseHandler,
  });

  @override
  Future<String> generateSemanticResponse(AiVoiceCommandRequest request) async {
    if (customRawResponse != null) {
      return customRawResponse!;
    }

    if (responseHandler != null) {
      return responseHandler!(request);
    }

    // Deterministic semantic inference based on transcript keywords
    final text = request.transcript.toLowerCase();

    if (text.contains('settle') || text.contains('paid') || text.contains('chuka')) {
      final merchant = _extractTargetName(text) ?? 'Sharma General Store';
      final amount = _extractAmountString(text);
      final paymentRef = text.contains('upi') ? 'UPI' : (text.contains('cash') ? 'Cash' : null);

      return jsonEncode({
        'intent': 'SETTLE_MERCHANT',
        'merchant_reference': merchant,
        'item': null,
        'category_reference': null,
        'amount_text': amount,
        'date_text': null,
        'note': null,
        'payment_reference': paymentRef,
      });
    }

    if (text.contains('naya merchant') || text.contains('create merchant') || text.contains('add merchant')) {
      final merchant = _extractTargetName(text) ?? 'New Store';
      return jsonEncode({
        'intent': 'CREATE_MERCHANT',
        'merchant_reference': merchant,
        'item': null,
        'category_reference': 'General',
        'amount_text': null,
        'date_text': null,
        'note': null,
        'payment_reference': null,
      });
    }

    if (text.contains('expense') || text.contains('kharch') || text.contains('dinner') || text.contains('petrol')) {
      final amount = _extractAmountString(text) ?? '100';
      final category = text.contains('petrol') ? 'Transport' : 'Food';

      return jsonEncode({
        'intent': 'ADD_EXPENSE',
        'merchant_reference': null,
        'item': null,
        'category_reference': category,
        'amount_text': amount,
        'date_text': null,
        'note': null,
        'payment_reference': null,
      });
    }

    // Default to ADD_PURCHASE
    final merchant = _extractTargetName(text) ?? 'Sharma Store';
    final amount = _extractAmountString(text) ?? '50';
    final item = text.contains('milk') || text.contains('doodh') ? 'Doodh' : 'General Item';

    return jsonEncode({
      'intent': 'ADD_PURCHASE',
      'merchant_reference': merchant,
      'item': item,
      'category_reference': null,
      'amount_text': amount,
      'date_text': null,
      'note': null,
      'payment_reference': null,
    });
  }

  String? _extractAmountString(String text) {
    final match = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(text);
    return match?.group(1);
  }

  String? _extractTargetName(String text) {
    if (text.contains('sharma')) return 'Sharma';
    if (text.contains('gupta')) return 'Gupta';
    if (text.contains('verma')) return 'Verma';
    return null;
  }
}

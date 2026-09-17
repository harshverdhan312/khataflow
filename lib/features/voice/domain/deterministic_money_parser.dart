import 'package:flutter/foundation.dart';

/// Single authoritative deterministic parser for converting spoken/textual monetary representations
/// (English, Hindi, Hinglish, Devanagari numerals, decimals, words) into integer paise.
///
/// Shared across both deterministic M5 voice command parser and M8.6.4 AI semantic resolver.
@immutable
class DeterministicMoneyParser {
  const DeterministicMoneyParser();

  static const Map<String, int> _spokenWordMap = <String, int>{
    'zero': 0,
    'ek': 100,
    'one': 100,
    'two': 200,
    'teen': 300,
    'three': 300,
    'chaar': 400,
    'char': 400,
    'four': 400,
    'paanch': 500,
    'panch': 500,
    'five': 500,
    'chhe': 600,
    'che': 600,
    'six': 600,
    'saat': 700,
    'sat': 700,
    'seven': 700,
    'aath': 800,
    'ath': 800,
    'eight': 800,
    'nau': 900,
    'nine': 900,
    'das': 1000,
    'dus': 1000,
    'ten': 1000,
    'bees': 2000,
    'twenty': 2000,
    'tees': 3000,
    'thirty': 3000,
    'chaalis': 4000,
    'chalis': 4000,
    'forty': 4000,
    'pachaas': 5000,
    'pachas': 5000,
    'fifty': 5000,
    'saath': 6000,
    'sath': 6000,
    'sixty': 6000,
    'sattar': 7000,
    'seventy': 7000,
    'assi': 8000,
    'eighty': 8000,
    'nabbe': 9000,
    'ninety': 9000,
    'sau': 10000,
    'hundred': 10000,
    'ek sau': 10000,
    'one hundred': 10000,
    'one hundred twenty': 12000,
    'one hundred and twenty': 12000,
    'dedh sau': 15000,
    'do sau': 20000,
    'two hundred': 20000,
    'two hundred fifty': 25000,
    'two hundred and fifty': 25000,
    'dhai sau': 25000,
    'teen sau': 30000,
    'three hundred': 30000,
    'chaar sau': 40000,
    'four hundred': 40000,
    'four hundred eighty': 48000,
    'four hundred and eighty': 48000,
    'paanch sau': 50000,
    'five hundred': 50000,
    'hazaar': 100000,
    'hazar': 100000,
    'thousand': 100000,
    'ek hazaar': 100000,
    'one thousand': 100000,
    'twelve hundred': 120000,
    'one thousand two hundred': 120000,
    'do hazaar': 200000,
    'two thousand': 200000,
    'दो सौ पचास': 25000,
    'पाँच सौ': 50000,
    'पांच सौ': 50000,
    'एक सौ बीस': 12000,
    'बारह सौ': 120000,
    'चार सौ अस्सी': 48000,
    'एक सौ': 10000,
    'दो सौ': 20000,
    'तीन सौ': 30000,
    'चार सौ': 40000,
    'पचास': 5000,
    'अस्सी': 8000,
    'सौ': 10000,
    'हजार': 100000,
    'हज़ार': 100000,
  };

  /// Parses any monetary string [input] into integer paise.
  ///
  /// Returns `null` if the input cannot be deterministically resolved to an integer paise value > 0.
  int? parseAmountToPaise(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('-') || trimmed.contains('minus') || trimmed.contains('negative')) {
      return null;
    }

    var text = convertDevanagariDigits(trimmed.toLowerCase());
    text = text
        .replaceAll(
          RegExp(
            r'\b(?:rs|inr|rupaye|rupees|rp|रुपये|रुपया|रुपए)\b|[₹\$\/\(\)]',
            caseSensitive: false,
          ),
          ' ',
        )
        .trim();
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // Check word numbers
    final wordPaise = _parseWordNumberToPaise(text);
    if (wordPaise != null) return wordPaise;

    // Remove commas (e.g. "1,000" -> "1000")
    text = text.replaceAll(',', '');

    // Numeric parsing
    final numValue = double.tryParse(text);
    if (numValue == null || numValue.isNaN || numValue.isInfinite || numValue <= 0) {
      return null;
    }

    // Convert to integer paise deterministically without double float drift
    final parts = text.split('.');
    if (parts.length == 1) {
      final rupees = int.tryParse(parts[0]);
      return rupees != null ? rupees * 100 : null;
    } else if (parts.length == 2) {
      final rupees = int.tryParse(parts[0]) ?? 0;
      var paiseStr = parts[1];
      if (paiseStr.length == 1) paiseStr += '0';
      if (paiseStr.length > 2) paiseStr = paiseStr.substring(0, 2);
      final paise = int.tryParse(paiseStr) ?? 0;
      return (rupees * 100) + paise;
    }

    return (numValue * 100).round();
  }

  /// Extracts the first identifiable monetary amount in integer paise from [text].
  int? extractFirstAmount(String text) {
    if (text.trim().isEmpty) return null;

    final normalized = convertDevanagariDigits(text);

    // 1. Try finding explicit numeric pattern like ₹250, 250.50, 250, 1,200
    final numericRegex = RegExp(
      r'[₹\$]?\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:rupaye|rupees|rs|रुपये|रुपया|रुपए)?',
      caseSensitive: false,
    );
    final match = numericRegex.firstMatch(normalized);
    if (match != null) {
      final val = parseAmountToPaise(match.group(1)!);
      if (val != null && val > 0) return val;
    }

    // 2. Check for multi-word phrases from _spokenWordMap (longest match first)
    final lower = normalized.toLowerCase();
    final sortedEntries = _spokenWordMap.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in sortedEntries) {
      final key = entry.key;
      if (RegExp(r'[\u0900-\u097F]').hasMatch(key)) {
        if (lower.contains(key)) return entry.value;
      } else {
        if (RegExp(r'\b' + RegExp.escape(key) + r'\b', caseSensitive: false).hasMatch(lower)) {
          return entry.value;
        }
      }
    }

    // 3. Fallback token-by-token
    final tokens = normalized.split(' ');
    for (final token in tokens) {
      final paise = parseAmountToPaise(token);
      if (paise != null && paise > 0) return paise;
    }
    return null;
  }

  /// Converts Devanagari numerals to Western digits.
  String convertDevanagariDigits(String input) {
    const devanagariDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    var result = input;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(devanagariDigits[i], '$i');
    }
    return result;
  }

  /// Map of spoken words for regex stripping in note extractors.
  Map<String, int> get spokenWordMap => _spokenWordMap;

  int? _parseWordNumberToPaise(String text) {
    final words = text.toLowerCase().trim();
    return _spokenWordMap[words];
  }
}

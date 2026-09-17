import 'package:flutter/foundation.dart';

/// Single authoritative deterministic parser for converting spoken or textual date expressions
/// into valid [DateTime] objects without guessing or inventing arbitrary dates.
///
/// Shared across both deterministic M5 voice command parser and M8.6.4 AI semantic resolver.
@immutable
class DeterministicDateParser {
  const DeterministicDateParser();

  static const Map<String, int> _monthMap = {
    'january': 1, 'jan': 1, 'जनवरी': 1,
    'february': 2, 'feb': 2, 'फरवरी': 2,
    'march': 3, 'mar': 3, 'मार्च': 3,
    'april': 4, 'apr': 4, 'अप्रैल': 4,
    'may': 5, 'मई': 5,
    'june': 6, 'jun': 6, 'जून': 6,
    'july': 7, 'jul': 7, 'जुलाई': 7,
    'august': 8, 'aug': 8, 'अगस्त': 8,
    'september': 9, 'sep': 9, 'sept': 9, 'सितंबर': 9, 'सितम्बर': 9,
    'october': 10, 'oct': 10, 'अक्टूबर': 10,
    'november': 11, 'nov': 11, 'नवंबर': 11, 'नवम्बर': 11,
    'december': 12, 'dec': 12, 'दिसंबर': 12, 'दिसम्बर': 12,
  };

  /// Parses [dateText] relative to [referenceDate] (defaults to `DateTime.now()`).
  ///
  /// Returns `null` if [dateText] cannot be deterministically resolved to a valid date.
  DateTime? parseDate(String dateText, {DateTime? referenceDate}) {
    final clean = dateText.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final now = referenceDate ?? DateTime.now();

    // 1. Relative keywords: today / aaj
    if (clean == 'today' || clean == 'aaj' || clean == 'आज') {
      return DateTime(now.year, now.month, now.day);
    }

    // 2. Relative keywords: yesterday / kal / beeta kal
    if (clean == 'yesterday' ||
        clean == 'kal' ||
        clean == 'beeta kal' ||
        clean == 'beete kal' ||
        clean == 'kal ka' ||
        clean == 'कल' ||
        clean == 'बीता कल') {
      final y = now.subtract(const Duration(days: 1));
      return DateTime(y.year, y.month, y.day);
    }

    // 3. Direct ISO 8601 parsing (e.g. "2026-09-18", "2026-09-18T10:00:00Z")
    final isoParsed = DateTime.tryParse(clean);
    if (isoParsed != null) {
      return DateTime(isoParsed.year, isoParsed.month, isoParsed.day);
    }

    // 4. Formats: "DD/MM/YYYY" or "DD-MM-YYYY" or "YYYY-MM-DD"
    final slashOrDashMatch = RegExp(r'^(\d{1,4})[\/\-](\d{1,2})[\/\-](\d{1,4})$').firstMatch(clean);
    if (slashOrDashMatch != null) {
      final p1 = int.parse(slashOrDashMatch.group(1)!);
      final p2 = int.parse(slashOrDashMatch.group(2)!);
      final p3 = int.parse(slashOrDashMatch.group(3)!);

      if (p1 > 1000) {
        // YYYY-MM-DD
        return _safeDate(p1, p2, p3);
      } else if (p3 > 1000) {
        // DD-MM-YYYY
        return _safeDate(p3, p2, p1);
      } else {
        // DD-MM-YY (assume current century)
        final year = 2000 + p3;
        return _safeDate(year, p2, p1);
      }
    }

    // 5. Formats: "10 September", "10 September 2026", "10th Sep", "September 10"
    // Remove ordinal suffixes: 1st, 2nd, 3rd, 4th, etc.
    final deordinalized = clean.replaceAll(RegExp(r'(\d+)(?:st|nd|rd|th)'), r'$1');

    // Pattern A: "10 September [2026]"
    final dayMonthMatch = RegExp(r'^(\d{1,2})\s+([a-zA-Z\u0900-\u097F]+)(?:\s+(\d{4}))?$').firstMatch(deordinalized);
    if (dayMonthMatch != null) {
      final day = int.parse(dayMonthMatch.group(1)!);
      final monthName = dayMonthMatch.group(2)!.toLowerCase();
      final month = _monthMap[monthName];
      final year = dayMonthMatch.group(3) != null ? int.parse(dayMonthMatch.group(3)!) : now.year;

      if (month != null) {
        return _safeDate(year, month, day);
      }
    }

    // Pattern B: "September 10 [2026]"
    final monthDayMatch = RegExp(r'^([a-zA-Z\u0900-\u097F]+)\s+(\d{1,2})(?:\s+(\d{4}))?$').firstMatch(deordinalized);
    if (monthDayMatch != null) {
      final monthName = monthDayMatch.group(1)!.toLowerCase();
      final day = int.parse(monthDayMatch.group(2)!);
      final month = _monthMap[monthName];
      final year = monthDayMatch.group(3) != null ? int.parse(monthDayMatch.group(3)!) : now.year;

      if (month != null) {
        return _safeDate(year, month, day);
      }
    }

    return null;
  }

  DateTime? _safeDate(int year, int month, int day) {
    if (year < 2000 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;

    try {
      final date = DateTime(year, month, day);
      // Validate day overflow (e.g. Feb 31 -> Mar 3 in Dart DateTime)
      if (date.year == year && date.month == month && date.day == day) {
        return date;
      }
    } catch (_) {}
    return null;
  }
}

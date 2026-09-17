import 'dart:convert';

import '../../../expense/domain/models/insight_type.dart';
import '../../domain/models/ai_insight.dart';
import '../../domain/models/ai_insight_exception.dart';

/// Parser that converts raw AI provider responses into structured [AIInsight] entities.
class AiResponseParser {
  const AiResponseParser();

  /// Parses raw HTTP response text into an [AIInsight].
  AIInsight parseResponse(String rawResponseBody, {DateTime? generatedAt}) {
    final timestamp = generatedAt ?? DateTime.now();

    if (rawResponseBody.trim().isEmpty) {
      throw const AIMalformedResponseException('Empty response body received from AI provider.');
    }

    dynamic decodedJson;
    try {
      decodedJson = jsonDecode(rawResponseBody);
    } catch (e) {
      throw AIMalformedResponseException('Failed to parse response body as JSON: $e');
    }

    if (decodedJson is! Map<String, dynamic>) {
      throw const AIMalformedResponseException('Provider response root must be a JSON object.');
    }

    // Handle Gemini response envelope if present: candidates[0].content.parts[0].text
    Map<String, dynamic> insightMap;
    if (decodedJson.containsKey('candidates')) {
      final candidates = decodedJson['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        throw const AIMalformedResponseException('No candidates returned in AI response envelope.');
      }
      final firstCandidate = candidates.first;
      if (firstCandidate is! Map<String, dynamic>) {
        throw const AIMalformedResponseException('Invalid candidate structure in AI response.');
      }
      final content = firstCandidate['content'];
      if (content is! Map<String, dynamic>) {
        throw const AIMalformedResponseException('Candidate content missing in AI response.');
      }
      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) {
        throw const AIMalformedResponseException('Candidate parts missing in AI response.');
      }
      final firstPart = parts.first;
      if (firstPart is! Map<String, dynamic> || !firstPart.containsKey('text')) {
        throw const AIMalformedResponseException('Candidate part text missing in AI response.');
      }

      final text = firstPart['text'] as String;
      insightMap = _extractJsonFromText(text);
    } else {
      // Direct gateway response
      insightMap = decodedJson;
    }

    final title = insightMap['title'];
    final explanation = insightMap['explanation'];
    final recommendation = insightMap['recommendation'];

    if (title is! String || title.trim().isEmpty) {
      throw const AIMalformedResponseException('Missing or invalid "title" in AI insight response.');
    }
    if (explanation is! String || explanation.trim().isEmpty) {
      throw const AIMalformedResponseException('Missing or invalid "explanation" in AI insight response.');
    }
    if (recommendation is! String || recommendation.trim().isEmpty) {
      throw const AIMalformedResponseException('Missing or invalid "recommendation" in AI insight response.');
    }

    final supportingInsightType = _parseInsightType(insightMap['supportingInsightType']);

    return AIInsight(
      title: title.trim(),
      explanation: explanation.trim(),
      recommendation: recommendation.trim(),
      supportingInsightType: supportingInsightType,
      generatedAt: timestamp,
    );
  }

  /// Extracts JSON content from a text string, stripping potential markdown fences.
  Map<String, dynamic> _extractJsonFromText(String text) {
    var cleanText = text.trim();

    if (cleanText.startsWith('```json')) {
      cleanText = cleanText.substring(7);
    } else if (cleanText.startsWith('```')) {
      cleanText = cleanText.substring(3);
    }

    if (cleanText.endsWith('```')) {
      cleanText = cleanText.substring(0, cleanText.length - 3);
    }

    cleanText = cleanText.trim();

    try {
      final decoded = jsonDecode(cleanText);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const AIMalformedResponseException('Decoded inner text is not a JSON object.');
    } catch (e) {
      throw AIMalformedResponseException('Failed to parse inner JSON from candidate text: $e');
    }
  }

  /// Maps a dynamic string to an [InsightType] enum value safely, returning `null` on unknown values.
  InsightType? _parseInsightType(dynamic value) {
    if (value == null || value is! String || value.trim().isEmpty) {
      return null;
    }

    final normalized = value.trim().toLowerCase();
    for (final type in InsightType.values) {
      if (type.name.toLowerCase() == normalized) {
        return type;
      }
    }

    return null;
  }
}

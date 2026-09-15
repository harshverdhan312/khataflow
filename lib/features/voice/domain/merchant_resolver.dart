import 'package:flutter/foundation.dart';
import '../../merchant/domain/merchant.dart';

/// Sealed result of resolving a raw merchant query string against active merchants.
sealed class MerchantResolutionResult {
  const MerchantResolutionResult();
}

/// A unique exact or unambiguous merchant match.
class ExactMerchantMatch extends MerchantResolutionResult {
  final Merchant merchant;

  const ExactMerchantMatch(this.merchant);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExactMerchantMatch &&
          runtimeType == other.runtimeType &&
          merchant == other.merchant;

  @override
  int get hashCode => merchant.hashCode;

  @override
  String toString() => 'ExactMerchantMatch(merchant: ${merchant.name})';
}

/// Multiple merchants match the query phrase; user disambiguation is required.
class AmbiguousMerchantMatch extends MerchantResolutionResult {
  final List<Merchant> candidates;
  final String query;

  const AmbiguousMerchantMatch({
    required this.candidates,
    required this.query,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmbiguousMerchantMatch &&
          runtimeType == other.runtimeType &&
          listEquals(candidates, other.candidates) &&
          query == other.query;

  @override
  int get hashCode => Object.hashAll(candidates) ^ query.hashCode;

  @override
  String toString() =>
      'AmbiguousMerchantMatch(candidates: ${candidates.map((c) => c.name).toList()}, query: "$query")';
}

/// No active merchant matches the query phrase.
class NoMerchantMatch extends MerchantResolutionResult {
  final String query;

  const NoMerchantMatch(this.query);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoMerchantMatch &&
          runtimeType == other.runtimeType &&
          query == other.query;

  @override
  int get hashCode => query.hashCode;

  @override
  String toString() => 'NoMerchantMatch(query: "$query")';
}

/// Utility for resolving merchant names against active store lists with ambiguity protection.
class MerchantResolver {
  const MerchantResolver();

  /// Resolves the raw [query] string against [activeMerchants].
  MerchantResolutionResult resolve({
    required String query,
    required List<Merchant> activeMerchants,
  }) {
    final cleanQuery = _normalize(query);
    if (cleanQuery.isEmpty || activeMerchants.isEmpty) {
      return NoMerchantMatch(query);
    }

    // 1. Direct exact match (case-insensitive)
    final exactMatches = activeMerchants
        .where((m) => _normalize(m.name) == cleanQuery)
        .toList();

    if (exactMatches.length == 1) {
      return ExactMerchantMatch(exactMatches.first);
    } else if (exactMatches.length > 1) {
      return AmbiguousMerchantMatch(candidates: exactMatches, query: query);
    }

    // 2. Prefix / Word match (e.g. "Sharma" matches "Sharma General Store" or "Sharma Sweets")
    final prefixMatches = activeMerchants.where((m) {
      final name = _normalize(m.name);
      return name.startsWith(cleanQuery) ||
          name.split(' ').any((word) => word == cleanQuery);
    }).toList();

    if (prefixMatches.length == 1) {
      return ExactMerchantMatch(prefixMatches.first);
    } else if (prefixMatches.length > 1) {
      return AmbiguousMerchantMatch(candidates: prefixMatches, query: query);
    }

    // 3. Substring / Contains match
    final substringMatches = activeMerchants.where((m) {
      final name = _normalize(m.name);
      return name.contains(cleanQuery) || cleanQuery.contains(name);
    }).toList();

    if (substringMatches.length == 1) {
      return ExactMerchantMatch(substringMatches.first);
    } else if (substringMatches.length > 1) {
      return AmbiguousMerchantMatch(candidates: substringMatches, query: query);
    }

    return NoMerchantMatch(query);
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
  }
}

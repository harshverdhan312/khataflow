import '../../../core/utils/validators.dart';
import '../../merchant/domain/merchant_category.dart';
import '../domain/voice_command.dart';
import '../domain/voice_command_parser.dart';
import '../domain/voice_transcript.dart';

/// Deterministic parser for converting Hinglish, Hindi, and English ledger speech
/// into structured [VoiceCommand] objects.
class DeterministicVoiceCommandParser implements VoiceCommandParser {
  const DeterministicVoiceCommandParser();

  @override
  VoiceParseResult parse(VoiceTranscript transcript) {
    final rawText = transcript.text.trim();
    if (rawText.isEmpty) {
      return const VoiceParseFailure('Transcript is empty.');
    }

    final normalized = _normalizeText(rawText);

    // 1. Try merchant creation parsing
    if (_isMerchantCreationIntent(normalized)) {
      return _parseMerchantCreation(rawText, normalized);
    }

    // 2. Try settlement parsing (full settlement or specific amount settlement)
    if (_isSettlementIntent(normalized)) {
      return _parseSettlement(rawText, normalized);
    }

    // 3. Try purchase parsing
    return _parsePurchase(rawText, normalized);
  }

  // ==========================================
  // MERCHANT CREATION INTENT & PARSING
  // ==========================================

  bool _isMerchantCreationIntent(String text) {
    final lower = text.toLowerCase().trim();
    final creationMarkers = [
      'ledger bana do',
      'ledger banao',
      'ledger banado',
      'ledger bana',
      'khata bana do',
      'khata banao',
      'khata banado',
      'khata bana',
      'khata kholo',
      'khata khol do',
      'shop add kar do',
      'shop add karo',
      'dukaan add kar do',
      'dukaan add karo',
      'store add kar do',
      'add as a merchant',
      'add as merchant',
      'create a ledger for',
      'create ledger for',
      'create a ledger',
      'create ledger',
      'new ledger for',
      'new ledger',
      'merchant ke roop mein add',
      'ko merchant add karo',
      'ko merchant banao',
      'as merchant',
    ];

    for (final marker in creationMarkers) {
      if (lower.contains(marker)) return true;
    }

    if (lower.startsWith('add ') && lower.contains('merchant')) return true;
    if (lower.startsWith('create ') && lower.contains('ledger')) return true;
    if (lower.startsWith('new ledger')) return true;

    return false;
  }

  VoiceParseResult _parseMerchantCreation(String original, String normalized) {
    var workingText = normalized;

    // 1. Extract optional UPI VPA
    String? extractedVpa;
    final vpaRegex = RegExp(
      r'(?:upi\s*id|upi|vpa)\s*[:=]?\s*([a-zA-Z0-9.\-_@\s]+?)(?:\s+(?:ka|ki|ke|ko|with|for)\b|$)',
      caseSensitive: false,
    );
    final vpaMatch = vpaRegex.firstMatch(workingText);

    if (vpaMatch != null) {
      var rawVpa = vpaMatch.group(1)!.trim();
      // Normalize whitespace around @ (e.g. "rahul @ oksbi" -> "rahul@oksbi")
      rawVpa = rawVpa.replaceAll(RegExp(r'\s*@\s*'), '@').replaceAll(RegExp(r'\s+'), '');

      // Remove the matched VPA portion from workingText
      workingText = workingText.replaceRange(vpaMatch.start, vpaMatch.end, ' ').trim();

      // If user spoke something like "UPI ID ...", validate it
      if (rawVpa.isNotEmpty) {
        final validationError = Validators.validateUpiVpa(rawVpa, isOptional: false);
        if (validationError != null) {
          return const VoiceParseFailure('Invalid UPI ID.');
        }
        extractedVpa = rawVpa;
      }
    } else {
      // Check for standalone VPA format username@handle
      final standaloneVpaMatch = RegExp(r'([a-zA-Z0-9.\-_]+@[a-zA-Z]+)').firstMatch(workingText);
      if (standaloneVpaMatch != null) {
        extractedVpa = standaloneVpaMatch.group(1);
        workingText = workingText.replaceRange(standaloneVpaMatch.start, standaloneVpaMatch.end, ' ').trim();
      }
    }

    // 2. Infer Category strictly and conservatively
    final inferredCategory = _inferCategory(workingText);

    // 3. Extract and clean merchant name
    var merchantRaw = workingText;

    // Strip prefix creation verbs
    merchantRaw = merchantRaw.replaceAll(
      RegExp(
        r'^(?:create\s+a\s+ledger\s+for|create\s+ledger\s+for|create\s+a\s+ledger|create\s+ledger|new\s+ledger\s+for|new\s+ledger|add\s+as\s+a\s+merchant|add\s+as\s+merchant|add)\s+',
        caseSensitive: false,
      ),
      ' ',
    );

    // Strip suffix creation phrases
    merchantRaw = merchantRaw.replaceAll(
      RegExp(
        r'\s+(?:ka|ki|ke)?\s*(?:ledger\s+bana\s+do|ledger\s+banao|ledger\s+banado|ledger\s+bana|khata\s+bana\s+do|khata\s+banao|khata\s+banado|khata\s+bana|khata\s+kholo|khata\s+khol\s+do|shop\s+add\s+kar\s+do|shop\s+add\s+karo|dukaan\s+add\s+kar\s+do|dukaan\s+add\s+karo|store\s+add\s+kar\s+do|ledger)\s*$',
        caseSensitive: false,
      ),
      ' ',
    );

    final cleanMerchant = _cleanMerchantName(merchantRaw);
    if (cleanMerchant.isEmpty) {
      return const VoiceParseFailure('No merchant was detected.');
    }

    return VoiceParseSuccess(
      CreateMerchantCommand(
        merchantName: cleanMerchant,
        category: inferredCategory,
        upiVpa: extractedVpa,
      ),
    );
  }

  MerchantCategory? _inferCategory(String text) {
    final lower = text.toLowerCase();

    // Grocery: sabji, sabzi, sabji wala, vegetable, grocery, kiryana, general store
    if (lower.contains('sabji') ||
        lower.contains('sabzi') ||
        lower.contains('vegetable') ||
        lower.contains('grocery') ||
        lower.contains('kiryana') ||
        lower.contains('general store')) {
      return MerchantCategory.grocery;
    }

    // Milk & Dairy: doodh, doodh wala, milk, dairy
    if (lower.contains('doodh') ||
        lower.contains('milk') ||
        lower.contains('dairy')) {
      return MerchantCategory.milk;
    }

    // Laundry: dhobi, laundry, dry clean
    if (lower.contains('dhobi') ||
        lower.contains('laundry') ||
        lower.contains('dry clean')) {
      return MerchantCategory.laundry;
    }

    // Business identifiers (shop, store, dukaan, merchant) do NOT infer a category
    return null;
  }

  // ==========================================
  // SETTLEMENT INTENT & PARSING
  // ==========================================

  bool _isSettlementIntent(String text) {
    final lower = text.toLowerCase().trim();
    final settlementMarkers = [
      'de diye',
      'de diya',
      'de di',
      'de dena',
      'chuka diya',
      'chuka diye',
      'chuka di',
      'chuka do',
      'pay kar diya',
      'pay kar diye',
      'pay kiya',
      'pay kardiye',
      'pay kardiya',
      'paid',
      'settle',
      'settled',
      'clear kar do',
      'clear karo',
      'payment settle',
      'poora udhaar',
      'poora hisab',
      'poora hisaab',
      'poori payment',
      'payment kar di',
      'payment kar diya',
      'ledger settle',
      'hisaab chuka',
    ];

    for (final marker in settlementMarkers) {
      if (lower.contains(marker)) return true;
    }

    if (lower.startsWith('pay ') ||
        lower.startsWith('paid ') ||
        lower.startsWith('settle ') ||
        lower.startsWith('clear ')) {
      return true;
    }

    return false;
  }

  VoiceParseResult _parseSettlement(String original, String normalized) {
    // Check for payment reference / UTR if present
    String? paymentRef;
    var workingText = normalized;

    final refRegex = RegExp(
      r'(?:ref(?:erence)?|utr|txn|transaction)\s*(?:id|number|no)?\s*[:=]?\s*([a-zA-Z0-9_-]+)',
      caseSensitive: false,
    );
    final refMatch = refRegex.firstMatch(workingText);
    if (refMatch != null) {
      paymentRef = refMatch.group(1);
      workingText = workingText.replaceRange(refMatch.start, refMatch.end, ' ').trim();
    }

    // Check if an explicit amount is present in the speech
    final amountPaise = _extractFirstAmount(workingText);

    // If NO amount is present, check for Full Settlement Command (SettleMerchantCommand)
    if (amountPaise == null || amountPaise <= 0) {
      return _parseFullSettlement(workingText);
    }

    // If an amount IS present, parse as specific amount settlement (RecordSettlementCommand)
    return _parseSpecificSettlement(workingText, amountPaise, paymentRef);
  }

  VoiceParseResult _parseFullSettlement(String workingText) {
    var text = workingText;

    // Remove prefix
    text = text.replaceAll(
      RegExp(
        r'^(?:settle\s+full\s+balance\s+for|settle\s+ledger\s+for|settle\s+payment\s+for|settle\s+balance\s+for|settle\s+for|settle|clear\s+payment\s+for|clear)\s+',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove full settlement action phrases
    text = text.replaceAll(
      RegExp(
        r'\s*(?:ki\s+poori\s+payment|ki\s+payment|ka\s+poora\s+udhaar|ka\s+poora\s+udhar|ka\s+poora\s+hisaab|ka\s+poora\s+hisab|ka\s+ledger|ka\s+hisaab|ka\s+hisab|ka\s+udhaar|ka\s+udhar)?\s*(?:settle\s+kar\s+do|settle\s+karo|clear\s+kar\s+do|clear\s+karo|chuka\s+do|chuka\s+de|kar\s+di|kar\s+diya|kar\s+diye|kar\s+do|settle|clear)\s*$',
        caseSensitive: false,
      ),
      ' ',
    );

    final cleanMerchant = _cleanMerchantName(text);
    if (cleanMerchant.isEmpty) {
      return const VoiceParseFailure('No merchant was detected.');
    }

    return VoiceParseSuccess(
      SettleMerchantCommand(merchantName: cleanMerchant),
    );
  }

  VoiceParseResult _parseSpecificSettlement(
    String workingText,
    int amountPaise,
    String? paymentRef,
  ) {
    // Pattern 1: English "Paid / Pay / Settle <amount> [to/with] <merchant>"
    final englishMatch = RegExp(
      r'^(?:paid|pay|settle)\s+([₹\$\d\.,\w\s]+?)\s+(?:to|with)\s+(.+?)(?:\s+(?:reference|utr|ref|txn).*|$)',
      caseSensitive: false,
    ).firstMatch(workingText);

    if (englishMatch != null) {
      final merchantStr = englishMatch.group(2)!.trim();
      final cleanMerchant = _cleanMerchantName(merchantStr);
      if (cleanMerchant.isEmpty) {
        return const VoiceParseFailure('No merchant was detected.');
      }

      return VoiceParseSuccess(
        RecordSettlementCommand(
          merchantName: cleanMerchant,
          amountPaise: amountPaise,
          paymentReference: paymentRef,
        ),
      );
    }

    // Pattern 2: Hinglish "<merchant> [ko / ka] <amount> [rupaye] [udhaar] [de diye / chuka diya / pay kar diya...]"
    final hinglishMatch = RegExp(
      r'^(.+?)\s+(?:ko|ka)\s+([₹\$\d\.,\w\s]+?)\s+(?:rupaye|rupees|rs)?\s*(?:udhaar|udhar|hisaab)?\s*(?:de diye|de diya|de di|chuka diya|chuka diye|chuka di|pay kar diye|pay kar diya|pay kiya|pay kardiye|pay kardiya|diya|diye)',
      caseSensitive: false,
    ).firstMatch(workingText);

    if (hinglishMatch != null) {
      final merchantStr = hinglishMatch.group(1)!.trim();
      final cleanMerchant = _cleanMerchantName(merchantStr);
      if (cleanMerchant.isEmpty) {
        return const VoiceParseFailure('No merchant was detected.');
      }

      return VoiceParseSuccess(
        RecordSettlementCommand(
          merchantName: cleanMerchant,
          amountPaise: amountPaise,
          paymentReference: paymentRef,
        ),
      );
    }

    // Fallback specific settlement search
    final cleanText = _stripSettlementKeywords(workingText);
    final cleanMerchant = _cleanMerchantName(cleanText);
    if (cleanMerchant.isEmpty) {
      return const VoiceParseFailure('No merchant was detected.');
    }

    return VoiceParseSuccess(
      RecordSettlementCommand(
        merchantName: cleanMerchant,
        amountPaise: amountPaise,
        paymentReference: paymentRef,
      ),
    );
  }

  // ==========================================
  // PURCHASE PARSING
  // ==========================================

  VoiceParseResult _parsePurchase(String original, String normalized) {
    var workingText = normalized;

    // 1. Strip trailing purchase verbs first ("liya", "liye", "li", "khareeda", "khareede", "bought", "buy", "le liya")
    workingText = workingText
        .replaceAll(
          RegExp(
            r'\s+(?:ka\s+|ki\s+|ke\s+)?(?:liya|liye|li|le liya|khareeda|khareede|bought|buy)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // 2. Check for explicit total phrase (e.g. "total 120" or "total 100 rupaye")
    int? explicitTotalPaise;
    final totalMatch = RegExp(
      r'\btotal\s+(?:hai\s+|ka\s+|amount\s+)?([₹\$\d\.,]+|\w+)',
      caseSensitive: false,
    ).firstMatch(workingText);

    if (totalMatch != null) {
      explicitTotalPaise = _parseAmountToPaise(totalMatch.group(1)!.trim());
      workingText = workingText.replaceRange(totalMatch.start, totalMatch.end, ' ').trim();
    }

    String rawMerchant = '';
    String itemsSection = '';

    // Strategy 1: English "Buy / Add <items> from <merchant>"
    final englishFromMatch = RegExp(
      r'^(?:buy|add|purchased?)\s+(.+?)\s+from\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(workingText);

    if (englishFromMatch != null) {
      itemsSection = englishFromMatch.group(1)!.trim();
      rawMerchant = englishFromMatch.group(2)!.trim();
    }
    // Strategy 2: English "From <merchant> buy / add <items>"
    else if (workingText.toLowerCase().startsWith('from ')) {
      final fromMatch = RegExp(
        r'^from\s+(.+?)\s+(?:buy|add|purchased?)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(workingText);
      if (fromMatch != null) {
        rawMerchant = fromMatch.group(1)!.trim();
        itemsSection = fromMatch.group(2)!.trim();
      }
    }
    // Strategy 3: Hinglish "<merchant> [ki dukaan / store / ke yahan] se <items>"
    else if (workingText.contains(' se ')) {
      final parts = workingText.split(' se ');
      if (parts.length == 2) {
        if (parts[1].trim().isEmpty) {
          final subMatch = RegExp(
            r'^([₹\$\d\.,\w\s]+?)\s+(?:ka|ki|ke)\s+(.+?)\s+(.+)$',
            caseSensitive: false,
          ).firstMatch(parts[0].trim());
          if (subMatch != null) {
            itemsSection = '${subMatch.group(2)!} ${subMatch.group(1)!}';
            rawMerchant = subMatch.group(3)!.trim();
          } else {
            rawMerchant = parts[0].trim();
          }
        } else {
          rawMerchant = parts[0].trim();
          itemsSection = parts[1].trim();
        }
      }
      rawMerchant = rawMerchant.replaceAll(RegExp(r'\s+(?:store|shop)\b', caseSensitive: false), ' ');
    }

    if (rawMerchant.isEmpty && itemsSection.isEmpty) {
      return const VoiceParseFailure('Could not understand the purchase command.');
    }

    final merchantName = _cleanMerchantName(rawMerchant);
    if (merchantName.isEmpty) {
      return const VoiceParseFailure('No merchant was detected.');
    }

    final items = _parsePurchaseItems(itemsSection);
    if (items.isEmpty) {
      return const VoiceParseFailure('Could not understand the purchase items or amounts.');
    }

    // Verify all item amounts are positive
    for (final item in items) {
      if (item.amountPaise <= 0) {
        return const VoiceParseFailure('Purchase item amount must be greater than zero.');
      }
      if (item.name.trim().isEmpty) {
        return const VoiceParseFailure('Purchase item name cannot be empty.');
      }
    }

    final calculatedTotal = items.fold<int>(0, (sum, item) => sum + item.amountPaise);
    if (calculatedTotal <= 0) {
      return const VoiceParseFailure('Total purchase amount must be greater than zero.');
    }

    // Verify explicit total if present
    if (explicitTotalPaise != null && explicitTotalPaise > 0) {
      if (explicitTotalPaise != calculatedTotal) {
        return const VoiceParseFailure('Item amounts do not match the total amount.');
      }
    }

    return VoiceParseSuccess(
      AddPurchaseCommand(
        merchantName: merchantName,
        items: items,
        totalAmountPaise: calculatedTotal,
      ),
    );
  }

  // ==========================================
  // ITEM EXTRACTION
  // ==========================================

  List<VoicePurchaseItem> _parsePurchaseItems(String itemsText) {
    final results = <VoicePurchaseItem>[];
    if (itemsText.trim().isEmpty) return results;

    // Split multi-item clauses joined by "aur", "and", ",", "&", "+"
    final clauses = itemsText.split(RegExp(r'\s+(?:aur|and|\&|\+)\s+|\s*,\s*', caseSensitive: false));

    for (final clause in clauses) {
      final trimmed = clause.trim();
      if (trimmed.isEmpty) continue;

      final item = _parseSingleItem(trimmed);
      if (item != null) {
        results.add(item);
      }
    }

    return results;
  }

  VoicePurchaseItem? _parseSingleItem(String clause) {
    var text = clause
        .replaceAll(RegExp(r'\b(?:ka|ki|ke|for)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Pattern 1: "<amount> <name>" (e.g. "60 doodh", "60 ka doodh", "₹40 bread")
    final amountFirstMatch = RegExp(
      r'^([₹\$\d\.,]+(?:\s*(?:rupaye|rupees|rs|paise))?)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);

    if (amountFirstMatch != null) {
      final maybeAmount = _parseAmountToPaise(amountFirstMatch.group(1)!);
      if (maybeAmount != null && maybeAmount > 0) {
        final name = _cleanItemName(amountFirstMatch.group(2)!);
        if (name.isNotEmpty) {
          return VoicePurchaseItem(name: name, amountPaise: maybeAmount);
        }
      }
    }

    // Pattern 2: "<name> <amount>" (e.g. "doodh 60", "milk 60 rupaye", "bread ₹40.50", "bread fifty")
    final amountLastMatch = RegExp(
      r'^(.+?)\s+([₹\$\d\.,]+(?:\s*(?:rupaye|rupees|rs|paise))?|\w+)\s*$',
      caseSensitive: false,
    ).firstMatch(text);

    if (amountLastMatch != null) {
      final maybeAmount = _parseAmountToPaise(amountLastMatch.group(2)!);
      if (maybeAmount != null && maybeAmount > 0) {
        final name = _cleanItemName(amountLastMatch.group(1)!);
        if (name.isNotEmpty) {
          return VoicePurchaseItem(name: name, amountPaise: maybeAmount);
        }
      }
    }

    // Pattern 3: Embedded search for money token anywhere
    final tokens = text.split(' ');
    for (var i = 0; i < tokens.length; i++) {
      final paise = _parseAmountToPaise(tokens[i]);
      if (paise != null && paise > 0) {
        final nameTokens = List<String>.from(tokens)..removeAt(i);
        final name = _cleanItemName(nameTokens.join(' '));
        if (name.isNotEmpty) {
          return VoicePurchaseItem(name: name, amountPaise: paise);
        }
      }
    }

    return null;
  }

  // ==========================================
  // MONEY / AMOUNT PARSING
  // ==========================================

  int? _parseAmountToPaise(String input) {
    var text = input.trim().toLowerCase();
    text = text.replaceAll(RegExp(r'\b(?:rs|inr|rupaye|rupees|rp)\b|[₹\$\/\-\(\)]', caseSensitive: false), ' ').trim();
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // Check word numbers
    final wordPaise = _parseWordNumberToPaise(text);
    if (wordPaise != null) return wordPaise;

    // Remove commas (e.g. "1,000" -> "1000")
    text = text.replaceAll(',', '');

    // Numeric parsing
    final numValue = double.tryParse(text);
    if (numValue == null || numValue.isNaN || numValue.isInfinite) {
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

  int? _parseWordNumberToPaise(String text) {
    final words = text.toLowerCase().trim();

    const wordMap = <String, int>{
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
      'dedh sau': 15000,
      'do sau': 20000,
      'two hundred': 20000,
      'dhai sau': 25000,
      'teen sau': 30000,
      'three hundred': 30000,
      'chaar sau': 40000,
      'four hundred': 40000,
      'paanch sau': 50000,
      'five hundred': 50000,
      'hazaar': 100000,
      'hazar': 100000,
      'thousand': 100000,
      'ek hazaar': 100000,
      'one thousand': 100000,
      'do hazaar': 200000,
      'two thousand': 200000,
    };

    return wordMap[words];
  }

  int? _extractFirstAmount(String text) {
    final tokens = text.split(' ');
    for (final token in tokens) {
      final paise = _parseAmountToPaise(token);
      if (paise != null && paise > 0) return paise;
    }
    return null;
  }

  // ==========================================
  // HELPERS
  // ==========================================

  String _normalizeText(String input) {
    return input
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

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

  String _stripSettlementKeywords(String text) {
    return text
        .replaceAll(
          RegExp(
            r'\b(?:ko|ka|ke|de\s+diye|de\s+diya|de\s+di|chuka\s+diya|chuka\s+diye|chuka\s+do|pay\s+kar\s+diye|pay\s+kar\s+diya|pay\s+kiya|udhaar|udhar|hisaab|paid|pay|settle|clear|to|with)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\d+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

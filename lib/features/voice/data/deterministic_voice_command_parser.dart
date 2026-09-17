import '../../../core/utils/validators.dart';
import '../../expense/domain/expense_category.dart';
import '../../merchant/domain/merchant_category.dart';
import '../domain/deterministic_category_resolver.dart';
import '../domain/deterministic_money_parser.dart';
import '../domain/voice_command.dart';
import '../domain/voice_command_parser.dart';
import '../domain/voice_transcript.dart';

/// Deterministic parser for converting Hinglish, Hindi, and English ledger speech
/// into structured [VoiceCommand] objects.
class DeterministicVoiceCommandParser implements VoiceCommandParser {
  final DeterministicMoneyParser moneyParser;
  final DeterministicCategoryResolver categoryResolver;

  const DeterministicVoiceCommandParser({
    this.moneyParser = const DeterministicMoneyParser(),
    this.categoryResolver = const DeterministicCategoryResolver(),
  });


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

    // 3. Try personal expense parsing if explicit expense cues are present
    if (_isExpenseIntent(normalized)) {
      return _parseExpense(rawText, normalized);
    }

    // 4. Try purchase parsing
    final purchaseResult = _parsePurchase(rawText, normalized);
    if (purchaseResult is VoiceParseSuccess) {
      return purchaseResult;
    }

    // 5. Fallback check for standalone expense intent (e.g. "Spent 250", "Expense 500")
    if (_isFallbackExpenseIntent(normalized)) {
      return _parseExpense(rawText, normalized);
    }

    return purchaseResult;
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
    return categoryResolver.resolveMerchantCategory(text);
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

    if (lower.startsWith('pay ') || lower.startsWith('paid ')) {
      if (lower.contains(' for ') && !lower.contains(' to ') && !lower.contains(' with ')) {
        return false;
      }
      return true;
    }

    if (lower.startsWith('settle ') ||
        lower.startsWith('settled ') ||
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
  // EXPENSE INTENT & PARSING
  // ==========================================

  bool _isExpenseIntent(String text) {
    final lower = text.toLowerCase().trim();

    // If explicit merchant purchase cues exist, preserve merchant ledger priority
    if (lower.contains(' ki dukaan se ') ||
        lower.contains(' store se ') ||
        lower.contains(' shop se ') ||
        lower.contains(' ke yahan se ')) {
      return false;
    }

    // Explicit expense keywords
    final expenseKeywords = [
      'kharch kiye',
      'kharch kiya',
      'kharch hua',
      'kharch hue',
      'kharch ho gaya',
      'kharch ho gaye',
      'kharcha kiya',
      'kharcha hua',
      'kharcha',
      'kharch',
      'खर्च किए',
      'खर्च किया',
      'खर्च हुआ',
      'खर्च हुए',
      'खर्च',
      'add an expense of',
      'add an expense for',
      'add an expense',
      'add expense of',
      'add expense for',
      'add expense',
      'personal expense',
      'expense of',
      'expense for',
    ];

    for (final kw in expenseKeywords) {
      if (lower.contains(kw)) return true;
    }

    if (lower.startsWith('spent ') || lower.startsWith('spend ')) {
      return true;
    }

    if (lower.startsWith('bought ') &&
        (lower.contains(' for ') || lower.contains(' of '))) {
      return true;
    }

    if (lower.startsWith('paid ') && lower.contains(' for ')) {
      return true;
    }

    // Pattern: "dukaan se ... ka samaan liya" or "... ka samaan liya"
    if (lower.contains('samaan liya') ||
        lower.contains('saman liya') ||
        lower.contains('सामान लिया') ||
        lower.contains('samaan khareeda') ||
        lower.contains('saman khareeda')) {
      return true;
    }

    // Pattern: "<category/item> pe <amount>" (e.g. "Food pe 250")
    if (RegExp(r'\bpe\s+[₹\$\d\.,\w\s]+', caseSensitive: false).hasMatch(lower) &&
        _inferExpenseCategory(lower) != null) {
      return true;
    }

    // Pattern: "<category/item> ke <amount> [rupaye]" (e.g. "Auto ke 80 rupaye", "Petrol ke 200")
    if (RegExp(r'\bke\s+[₹\$\d\.,\w\s]+', caseSensitive: false).hasMatch(lower) &&
        _inferExpenseCategory(lower) != null) {
      return true;
    }

    // Pattern: Hindi "<category> पर <amount>" or "<category> के <amount>"
    if ((lower.contains(' पर ') || lower.contains(' के ')) &&
        _inferExpenseCategory(lower) != null &&
        RegExp(r'[\d\u0966-\u096F]+').hasMatch(lower)) {
      return true;
    }

    return false;
  }

  bool _isFallbackExpenseIntent(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.startsWith('spent') ||
        lower.startsWith('spend') ||
        lower.startsWith('expense') ||
        lower.contains('kharch') ||
        lower.contains('खर्च')) {
      return true;
    }
    return false;
  }

  VoiceParseResult _parseExpense(String original, String normalized) {
    // 1. Extract amount in integer paise
    final amountPaise = _extractFirstAmount(normalized);
    if (amountPaise == null || amountPaise <= 0) {
      return const VoiceParseFailure('Expense amount must be greater than zero.');
    }

    // 2. Infer Category strictly and conservatively
    final category = _inferExpenseCategory(normalized);

    // 3. Extract Note from remaining spoken context
    final note = _extractExpenseNote(normalized, category);

    return VoiceParseSuccess(
      AddExpenseCommand(
        amountPaise: amountPaise,
        category: category,
        note: note,
        expenseDate: DateTime.now(),
      ),
    );
  }

  ExpenseCategory? _inferExpenseCategory(String text) {
    return categoryResolver.resolveExpenseCategory(text);
  }

  String? _extractExpenseNote(String text, ExpenseCategory? category) {
    var working = text;

    // Remove numbers and currency tokens
    working = working.replaceAll(
      RegExp(
        r'[₹\$]?\s*\d+(?:,\d+)*(?:\.\d+)?\s*(?:rupaye|rupees|rs|inr|रुपये|रुपया|रुपए)?',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove multi-word numbers
    for (final word in moneyParser.spokenWordMap.keys) {
      working = working.replaceAll(
        RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false),
        ' ',
      );
    }

    // Remove command verbs and syntax prepositions
    working = working.replaceAll(
      RegExp(
        r'\b(?:spent|spend|add\s+an\s+expense\s+of|add\s+an\s+expense\s+for|add\s+an\s+expense|add\s+expense\s+of|add\s+expense\s+for|add\s+expense|personal\s+expense|expense\s+of|expense\s+for|expense|paid|bought|buy|on|for|of|pe|ke|ka|ki|par|kharch\s+kiye|kharch\s+kiya|kharch\s+hua|kharch\s+hue|kharch\s+ho\s+gaya|kharch\s+ho\s+gaye|kharcha\s+kiya|kharcha\s+hua|kharcha|kharch|liye|liya|li|se|dukaan\s+se|dukan\s+se|a|an|the)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove Hindi syntax phrases
    working = working.replaceAll(
      RegExp(
        r'(?:खर्च\s+किए|खर्च\s+किया|खर्च\s+हुआ|खर्च\s+हुए|खर्च|पर|के|का|की|से|लिए|लिया|दुकान\s+से|दुकान)',
      ),
      ' ',
    );

    working = working.replaceAll(RegExp(r'[^\w\s\u0900-\u097F]'), ' ');
    working = working.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (working.isEmpty) return null;

    final lower = working.toLowerCase();

    // Redundant generic category labels are not stored as notes
    const genericCategoryWords = [
      'food', 'transport', 'shopping', 'bills', 'bill', 'entertainment',
      'health', 'education', 'other', 'खाने', 'खाना', 'शॉपिंग', 'बिल',
      'मनोरंजन', 'स्वास्थ्य', 'शिक्षा'
    ];
    if (genericCategoryWords.contains(lower)) {
      return null;
    }

    if (category != null && lower == category.name.toLowerCase()) {
      return null;
    }

    if (working.length > 200) {
      working = working.substring(0, 200).trim();
    }

    return working.isNotEmpty ? working.toLowerCase() : null;
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
    return moneyParser.parseAmountToPaise(input);
  }

  int? _extractFirstAmount(String text) {
    return moneyParser.extractFirstAmount(text);
  }

  // ==========================================
  // HELPERS
  // ==========================================

  String _convertDevanagariDigits(String input) {
    return moneyParser.convertDevanagariDigits(input);
  }

  String _normalizeText(String input) {
    var text = _convertDevanagariDigits(input);
    return text
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

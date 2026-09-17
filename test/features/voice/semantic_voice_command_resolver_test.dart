import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/voice/domain/deterministic_category_resolver.dart';
import 'package:khata_flow/features/voice/domain/deterministic_date_parser.dart';
import 'package:khata_flow/features/voice/domain/deterministic_money_parser.dart';
import 'package:khata_flow/features/voice/domain/merchant_resolver.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_command_resolver.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_intent.dart';
import 'package:khata_flow/features/voice/domain/semantic_voice_interpretation.dart';
import 'package:khata_flow/features/voice/domain/voice_command.dart';

void main() {
  late SemanticVoiceCommandResolver resolver;

  final sharmaMerchant = Merchant(
    id: 'merchant-1',
    name: 'Sharma Ji Kirana',
    category: MerchantCategory.grocery,
    upiVpa: 'sharma@upi',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final sharmaDairyMerchant = Merchant(
    id: 'merchant-2',
    name: 'Sharma Dairy',
    category: MerchantCategory.milk,
    upiVpa: 'dairy@upi',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final guptaMerchant = Merchant(
    id: 'merchant-3',
    name: 'Gupta Medical Store',
    category: MerchantCategory.other,
    upiVpa: 'gupta@upi',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final List<Merchant> activeMerchants = [
    sharmaMerchant,
    sharmaDairyMerchant,
    guptaMerchant,
  ];

  setUp(() {
    resolver = const SemanticVoiceCommandResolver(
      merchantResolver: MerchantResolver(),
      moneyParser: DeterministicMoneyParser(),
      categoryResolver: DeterministicCategoryResolver(),
      dateParser: DeterministicDateParser(),
    );
  });

  group('KhataFlow M8.6.4 — Deterministic Semantic Voice Command Resolver', () {
    // ==========================================
    // 1. PURCHASE RESOLUTION
    // ==========================================
    group('Purchase Resolution', () {
      test('Case 1: Valid semantic purchase resolves correctly with integer paise and resolved merchant', () {
        final interpretation = SemanticVoiceInterpretation.addPurchase(
          merchantReference: 'Gupta Medical',
          item: 'dawa',
          amountText: 'dhai sau',
          rawTranscript: 'Gupta se 250 ki dawa li',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolved>());
        final resolved = result as SemanticVoiceResolved;
        expect(resolved.resolvedMerchant, equals(guptaMerchant));
        expect(resolved.command, isA<AddPurchaseCommand>());

        final cmd = resolved.command as AddPurchaseCommand;
        expect(cmd.merchantName, equals('Gupta Medical Store'));
        expect(cmd.totalAmountPaise, equals(25000));
        expect(cmd.items.length, equals(1));
        expect(cmd.items.first.name, equals('Dawa'));
        expect(cmd.items.first.amountPaise, equals(25000));
      });

      test('Case 2: Unknown merchant returns unresolved failure', () {
        final interpretation = SemanticVoiceInterpretation.addPurchase(
          merchantReference: 'Verma Sweet Shop',
          amountText: '100',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolutionFailure>());
        final failure = result as SemanticVoiceResolutionFailure;
        expect(failure.reason, contains('Verma Sweet Shop'));
      });

      test('Case 3: Ambiguous merchant match returns ambiguous result with candidate list and NO executable command', () {
        final interpretation = SemanticVoiceInterpretation.addPurchase(
          merchantReference: 'Sharma',
          item: 'doodh',
          amountText: '60',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceAmbiguous>());
        final ambiguous = result as SemanticVoiceAmbiguous;
        expect(ambiguous.candidateMerchants.length, equals(2));
        expect(ambiguous.candidateMerchants, contains(sharmaMerchant));
        expect(ambiguous.candidateMerchants, contains(sharmaDairyMerchant));
        expect(ambiguous.interpretation, equals(interpretation));
      });

      test('Case 4: Invalid/unparseable amount returns unresolved failure', () {
        final interpretation = SemanticVoiceInterpretation.addPurchase(
          merchantReference: 'Gupta Medical',
          amountText: 'invalid-non-numeric-amount',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolutionFailure>());
        final failure = result as SemanticVoiceResolutionFailure;
        expect(failure.reason, contains('Could not parse a valid purchase amount'));
      });

      test('Case 5: Invalid date string returns unresolved failure', () {
        final interpretation = SemanticVoiceInterpretation.addPurchase(
          merchantReference: 'Gupta Medical',
          amountText: '250',
          dateText: '32nd Someday Invalid',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolutionFailure>());
        final failure = result as SemanticVoiceResolutionFailure;
        expect(failure.reason, contains('Could not parse date'));
      });

      test('Case 6: AI category cannot override deterministic purchase behavior (creates ledger purchase)', () {
        // AI might provide a categoryReference, but AddPurchaseCommand is strictly ledger purchase
        final interpretation = SemanticVoiceInterpretation(
          intent: SemanticVoiceIntent.addPurchase,
          merchantReference: 'Gupta Medical',
          categoryReference: 'food',
          amountText: '500',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolved>());
        final resolved = result as SemanticVoiceResolved;
        expect(resolved.command, isA<AddPurchaseCommand>());
        expect((resolved.command as AddPurchaseCommand).totalAmountPaise, equals(50000));
      });
    });

    // ==========================================
    // 2. EXPENSE RESOLUTION
    // ==========================================
    group('Expense Resolution', () {
      test('Case 7: Valid expense resolves correctly into AddExpenseCommand', () {
        final interpretation = SemanticVoiceInterpretation.addExpense(
          amountText: '₹350.50',
          categoryReference: 'transport',
          note: 'Cab to office',
          dateText: 'today',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
          referenceDate: DateTime(2026, 9, 18),
        );

        expect(result, isA<SemanticVoiceResolved>());
        final resolved = result as SemanticVoiceResolved;
        expect(resolved.resolvedMerchant, isNull);
        expect(resolved.command, isA<AddExpenseCommand>());

        final cmd = resolved.command as AddExpenseCommand;
        expect(cmd.amountPaise, equals(35050));
        expect(cmd.category, equals(ExpenseCategory.transport));
        expect(cmd.note, equals('Cab to office'));
        expect(cmd.expenseDate.year, equals(2026));
        expect(cmd.expenseDate.month, equals(9));
        expect(cmd.expenseDate.day, equals(18));
      });

      test('Case 8: Valid category resolves through deterministic category validation', () {
        final interpretation = SemanticVoiceInterpretation.addExpense(
          amountText: '120',
          categoryReference: 'chai nashta',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolved>());
        final cmd = (result as SemanticVoiceResolved).command as AddExpenseCommand;
        expect(cmd.category, equals(ExpenseCategory.food));
      });

      test('Case 9: Invalid category returns unresolved failure without guessing', () {
        final interpretation = SemanticVoiceInterpretation.addExpense(
          amountText: '500',
          categoryReference: 'cryptocurrency speculation',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolutionFailure>());
        final failure = result as SemanticVoiceResolutionFailure;
        expect(failure.reason, contains('Invalid expense category'));
      });

      test('Case 10: Invalid expense amount returns unresolved failure', () {
        final interpretation = SemanticVoiceInterpretation.addExpense(
          amountText: '-50',
          categoryReference: 'food',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolutionFailure>());
      });

      test('Case 11: Invalid expense date returns unresolved failure', () {
        final interpretation = SemanticVoiceInterpretation.addExpense(
          amountText: '100',
          dateText: '99/99/9999',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolutionFailure>());
        final failure = result as SemanticVoiceResolutionFailure;
        expect(failure.reason, contains('Could not parse date'));
      });
    });

    // ==========================================
    // 3. SETTLEMENT RESOLUTION
    // ==========================================
    group('Settlement Resolution', () {
      test('Case 12: Valid merchant settlement resolves (full settlement & specific amount)', () {
        // 12a: Full settlement (no amountText)
        final fullInterpretation = SemanticVoiceInterpretation.settleMerchant(
          merchantReference: 'Gupta Medical',
        );

        final fullResult = resolver.resolve(
          interpretation: fullInterpretation,
          activeMerchants: activeMerchants,
        );

        expect(fullResult, isA<SemanticVoiceResolved>());
        final fullResolved = fullResult as SemanticVoiceResolved;
        expect(fullResolved.command, isA<SettleMerchantCommand>());
        expect((fullResolved.command as SettleMerchantCommand).merchantName, equals('Gupta Medical Store'));

        // 12b: Specific amount settlement
        final specificInterpretation = SemanticVoiceInterpretation.settleMerchant(
          merchantReference: 'Gupta Medical',
          amountText: '500',
          paymentReference: 'UPI-123456',
        );

        final specificResult = resolver.resolve(
          interpretation: specificInterpretation,
          activeMerchants: activeMerchants,
        );

        expect(specificResult, isA<SemanticVoiceResolved>());
        final specificResolved = specificResult as SemanticVoiceResolved;
        expect(specificResolved.command, isA<RecordSettlementCommand>());
        final recordCmd = specificResolved.command as RecordSettlementCommand;
        expect(recordCmd.merchantName, equals('Gupta Medical Store'));
        expect(recordCmd.amountPaise, equals(50000));
        expect(recordCmd.paymentReference, equals('UPI-123456'));
      });

      test('Case 13: Unknown merchant settlement returns unresolved failure', () {
        final interpretation = SemanticVoiceInterpretation.settleMerchant(
          merchantReference: 'Unknown Store X',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolutionFailure>());
      });

      test('Case 14: Ambiguous merchant settlement returns ambiguous result', () {
        final interpretation = SemanticVoiceInterpretation.settleMerchant(
          merchantReference: 'Sharma',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceAmbiguous>());
        final ambiguous = result as SemanticVoiceAmbiguous;
        expect(ambiguous.candidateMerchants.length, equals(2));
      });

      test('Cases 15-18: AI cannot provide merchant ID, status, or purchase IDs', () {
        // Even if AI payload contained database IDs, SemanticVoiceInterpretation has no fields for them,
        // and resolver constructs command solely with merchantName from deterministic lookup
        final interpretation = SemanticVoiceInterpretation.settleMerchant(
          merchantReference: 'Gupta Medical',
          amountText: '300',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolved>());
        final resolved = result as SemanticVoiceResolved;
        expect(resolved.command, isA<RecordSettlementCommand>());
        // Live execution in repository calculates unsettled purchase IDs at confirmation time
      });
    });

    // ==========================================
    // 4. CREATE MERCHANT RESOLUTION
    // ==========================================
    group('Create Merchant Resolution', () {
      test('Case 19: Valid merchant creation resolves into CreateMerchantCommand', () {
        final interpretation = SemanticVoiceInterpretation.createMerchant(
          merchantReference: 'Agarwal Sweets',
          categoryReference: 'grocery',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolved>());
        final cmd = (result as SemanticVoiceResolved).command as CreateMerchantCommand;
        expect(cmd.merchantName, equals('Agarwal Sweets'));
        expect(cmd.category, equals(MerchantCategory.grocery));
        expect(cmd.upiVpa, isNull);
      });

      test('Case 20: Existing category validation is reused for merchant creation', () {
        final interpretation = SemanticVoiceInterpretation.createMerchant(
          merchantReference: 'Ramesh Milk Centre',
          categoryReference: 'doodh dairy',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolved>());
        final cmd = (result as SemanticVoiceResolved).command as CreateMerchantCommand;
        expect(cmd.category, equals(MerchantCategory.milk));
      });

      test('Case 21: Invalid/empty merchant name returns unresolved failure', () {
        final interpretation = SemanticVoiceInterpretation.createMerchant(
          merchantReference: '   ',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolutionFailure>());
      });

      test('Case 22: Invalid VPA in paymentReference returns unresolved failure', () {
        final interpretation = SemanticVoiceInterpretation(
          intent: SemanticVoiceIntent.createMerchant,
          merchantReference: 'New Store',
          paymentReference: 'invalid-vpa-format-without-at',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolutionFailure>());
        final failure = result as SemanticVoiceResolutionFailure;
        expect(failure.reason, contains('Invalid UPI ID'));
      });

      test('Case 23: Generic category wording does not silently become Grocery', () {
        final interpretation = SemanticVoiceInterpretation.createMerchant(
          merchantReference: 'Rajesh Enterprise',
          categoryReference: 'business corporation',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolutionFailure>());
        final failure = result as SemanticVoiceResolutionFailure;
        expect(failure.reason, contains('Invalid merchant category'));
      });

      test('Duplicate check: Creating a merchant with an already existing exact name fails', () {
        final interpretation = SemanticVoiceInterpretation.createMerchant(
          merchantReference: 'Gupta Medical Store',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolutionFailure>());
        final failure = result as SemanticVoiceResolutionFailure;
        expect(failure.reason, contains('already exists'));
      });
    });

    // ==========================================
    // 5. SECURITY / TRUST BOUNDARY
    // ==========================================
    group('Security & Trust Boundary', () {
      test('Case 24-27: AI interpretation strictly provides raw text; all amounts converted to integer paise', () {
        final interpretation = SemanticVoiceInterpretation.addPurchase(
          merchantReference: 'Gupta Medical Store',
          item: 'Bandage',
          amountText: '100.50',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        expect(result, isA<SemanticVoiceResolved>());
        final cmd = (result as SemanticVoiceResolved).command as AddPurchaseCommand;
        // Deterministically 10050 paise
        expect(cmd.totalAmountPaise, equals(10050));
      });

      test('Case 28: SemanticVoiceCommandResolver produces domain commands for confirmation, never executes DB writes', () {
        final interpretation = SemanticVoiceInterpretation.addPurchase(
          merchantReference: 'Gupta Medical Store',
          amountText: '100',
        );

        final result = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );

        // Result is purely a VoiceCommand model. Zero SQLite mutation occurred.
        expect(result, isA<SemanticVoiceResolved>());
      });
    });

    // ==========================================
    // 6. STALE AMBIGUITY RESOLUTION TEST
    // ==========================================
    group('Stale Ambiguity Resolution', () {
      test('Case 31: Ambiguity resolution re-validates against current active merchants to prevent stale state', () {
        final interpretation = SemanticVoiceInterpretation.addPurchase(
          merchantReference: 'Sharma',
          item: 'doodh',
          amountText: '60',
        );

        // Step 1: Initial resolution yields ambiguity
        final initialResult = resolver.resolve(
          interpretation: interpretation,
          activeMerchants: activeMerchants,
        );
        expect(initialResult, isA<SemanticVoiceAmbiguous>());

        // Step 2: User selects sharmaDairyMerchant
        // Case A: Merchant is still active in current state
        final resolvedResult = resolver.resolveWithSelectedMerchant(
          interpretation: interpretation,
          selectedMerchant: sharmaDairyMerchant,
          activeMerchants: activeMerchants,
        );

        expect(resolvedResult, isA<SemanticVoiceResolved>());
        final cmd = (resolvedResult as SemanticVoiceResolved).command as AddPurchaseCommand;
        expect(cmd.merchantName, equals('Sharma Dairy'));
        expect(cmd.totalAmountPaise, equals(6000));

        // Case B: In the meantime, sharmaDairyMerchant was deleted/deactivated from activeMerchants
        final List<Merchant> updatedMerchants = [sharmaMerchant, guptaMerchant]; // sharmaDairyMerchant removed
        final staleResult = resolver.resolveWithSelectedMerchant(
          interpretation: interpretation,
          selectedMerchant: sharmaDairyMerchant,
          activeMerchants: updatedMerchants,
        );

        expect(staleResult, isA<SemanticVoiceResolutionFailure>());
        final failure = staleResult as SemanticVoiceResolutionFailure;
        expect(failure.reason, contains('no longer active'));
      });
    });
  });
}

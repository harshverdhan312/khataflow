import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/voice/data/deterministic_voice_command_parser.dart';
import 'package:khata_flow/features/voice/domain/voice_command.dart';
import 'package:khata_flow/features/voice/domain/voice_command_parser.dart';
import 'package:khata_flow/features/voice/domain/voice_transcript.dart';

void main() {
  const parser = DeterministicVoiceCommandParser();

  VoiceParseResult parseText(String text, {String locale = 'en_IN'}) {
    return parser.parse(
      VoiceTranscript(
        text: text,
        locale: locale,
        isFinal: true,
        capturedAt: DateTime(2026, 9, 17),
      ),
    );
  }

  group('DeterministicVoiceCommandParser — Voice Expenses (M6.5)', () {
    group('English Commands', () {
      test('parses "Spent 250 on food" into AddExpenseCommand with Food category and null note', () {
        final result = parseText('Spent 250 on food');
        expect(result, isA<VoiceParseSuccess>());
        final cmd = (result as VoiceParseSuccess).command;
        expect(cmd, isA<AddExpenseCommand>());
        final expenseCmd = cmd as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, isNull);
      });

      test('parses "Spent 120 on transport" into AddExpenseCommand with Transport category', () {
        final result = parseText('Spent 120 on transport');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(12000));
        expect(expenseCmd.category, equals(ExpenseCategory.transport));
        expect(expenseCmd.note, isNull);
      });

      test('parses "Bought groceries for 480" into AddExpenseCommand with Shopping category and note', () {
        final result = parseText('Bought groceries for 480');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(48000));
        expect(expenseCmd.category, equals(ExpenseCategory.shopping));
        expect(expenseCmd.note, equals('groceries'));
      });

      test('parses "Paid 100 for movie" into AddExpenseCommand with Entertainment category', () {
        final result = parseText('Paid 100 for movie');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(10000));
        expect(expenseCmd.category, equals(ExpenseCategory.entertainment));
        expect(expenseCmd.note, equals('movie'));
      });

      test('parses "Add an expense of 120 for transport" correctly', () {
        final result = parseText('Add an expense of 120 for transport');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(12000));
        expect(expenseCmd.category, equals(ExpenseCategory.transport));
      });

      test('parses "Spent 250 on lunch" preserving "lunch" as note with Food category', () {
        final result = parseText('Spent 250 on lunch');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, equals('lunch'));
      });

      test('parses "I spent 250 rupees on food" into AddExpenseCommand with Food category and null note', () {
        final result = parseText('I spent 250 rupees on food');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, isNull);
      });…\customer-first-ledger > flutter test t

      test('parses "I spent ₹250 on food" into AddExpenseCommand with Food category', () {
        final result = parseText('I spent ₹250 on food');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, isNull);
      });

      test('parses "I spent 250 on food" into AddExpenseCommand with Food category', () {
        final result = parseText('I spent 250 on food');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, isNull);
      });

      test('parses "I spent 100 rupees on food" into AddExpenseCommand with ₹100 Food category', () {
        final result = parseText('I spent 100 rupees on food');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(10000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, isNull);
      });

      test('parses "I\'ve spent 250 rupees on food" into AddExpenseCommand with Food category', () {
        final result = parseText("I've spent 250 rupees on food");
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, isNull);
      });

      test('parses "I paid 250 rupees for food" into AddExpenseCommand with Food category', () {
        final result = parseText('I paid 250 rupees for food');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, isNull);
      });

      test('parses "I paid 250 rupees on food" into AddExpenseCommand with Food category', () {
        final result = parseText('I paid 250 rupees on food');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, isNull);
      });

      test('parses "Spent 250 rupees on food" into AddExpenseCommand with Food category', () {
        final result = parseText('Spent 250 rupees on food');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, isNull);
      });

      test('parses "I spent 250 on lunch" preserving "lunch" as note with Food category', () {
        final result = parseText('I spent 250 on lunch');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, equals('lunch'));
      });
    });

    group('Hinglish Commands', () {
      test('parses "Food pe 250 kharch kiye" into AddExpenseCommand with Food category', () {
        final result = parseText('Food pe 250 kharch kiye');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, isNull);
      });

      test('parses "Auto ke 80 rupaye" into AddExpenseCommand with Transport category and "auto" note', () {
        final result = parseText('Auto ke 80 rupaye');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(8000));
        expect(expenseCmd.category, equals(ExpenseCategory.transport));
        expect(expenseCmd.note, equals('auto'));
      });

      test('parses "Shopping pe 1200 kharch hua" into AddExpenseCommand with Shopping category', () {
        final result = parseText('Shopping pe 1200 kharch hua');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(120000));
        expect(expenseCmd.category, equals(ExpenseCategory.shopping));
        expect(expenseCmd.note, isNull);
      });

      test('parses "Dukaan se 350 ka samaan liya" into AddExpenseCommand with Shopping category', () {
        final result = parseText('Dukaan se 350 ka samaan liya');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(35000));
        expect(expenseCmd.category, equals(ExpenseCategory.shopping));
        expect(expenseCmd.note, equals('samaan'));
      });
    });

    group('Hindi Commands', () {
      test('parses "खाने पर 250 रुपये खर्च किए" into AddExpenseCommand with Food category', () {
        final result = parseText('खाने पर 250 रुपये खर्च किए', locale: 'hi_IN');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
        expect(expenseCmd.note, isNull);
      });

      test('parses "ऑटो के 80 रुपये" into AddExpenseCommand with Transport category and "ऑटो" note', () {
        final result = parseText('ऑटो के 80 रुपये', locale: 'hi_IN');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(8000));
        expect(expenseCmd.category, equals(ExpenseCategory.transport));
        expect(expenseCmd.note, equals('ऑटो'));
      });

      test('parses "शॉपिंग पर 1200 रुपये खर्च हुए" into AddExpenseCommand with Shopping category', () {
        final result = parseText('शॉपिंग पर 1200 रुपये खर्च हुए', locale: 'hi_IN');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(120000));
        expect(expenseCmd.category, equals(ExpenseCategory.shopping));
        expect(expenseCmd.note, isNull);
      });

      test('parses Devanagari numerals "खाने पर २५० रुपये खर्च किए"', () {
        final result = parseText('खाने पर २५० रुपये खर्च किए', locale: 'hi_IN');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, equals(ExpenseCategory.food));
      });
    });

    group('Category Inference across all 8 Categories', () {
      test('infers Food category from restaurant / chai / dinner / nashta', () {
        expect(((parseText('Spent 450 at restaurant') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.food));
        expect(((parseText('Chai pe 30 kharch kiye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.food));
        expect(((parseText('Dinner pe 600 kharch hua') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.food));
      });

      test('infers Transport category from petrol / metro / uber / cab', () {
        expect(((parseText('Petrol pe 500 kharch kiye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.transport));
        expect(((parseText('Metro ke 40 rupaye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.transport));
        expect(((parseText('Cab ke 250 kharch hue') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.transport));
      });

      test('infers Shopping category from clothes / kapde / groceries', () {
        expect(((parseText('Bought clothes for 1500') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.shopping));
        expect(((parseText('Kapde pe 2000 kharch kiye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.shopping));
      });

      test('infers Bills category from electricity / recharge / rent', () {
        expect(((parseText('Electricity bill pe 1200 kharch kiye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.bills));
        expect(((parseText('Mobile recharge ke 299 rupaye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.bills));
        expect(((parseText('Rent pe 8000 kharch hua') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.bills));
      });

      test('infers Entertainment category from movie / cinema / gaming', () {
        expect(((parseText('Movie ticket pe 300 kharch kiye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.entertainment));
        expect(((parseText('Gaming pe 500 kharch hua') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.entertainment));
      });

      test('infers Health category from medicine / doctor / pharmacy', () {
        expect(((parseText('Medicine pe 450 kharch kiye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.health));
        expect(((parseText('Doctor fees ke 500 rupaye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.health));
        expect(((parseText('Dawai ke 200 rupaye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.health));
      });

      test('infers Education category from books / fees / tuition / course', () {
        expect(((parseText('Books pe 600 kharch kiye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.education));
        expect(((parseText('Tuition fees ke 1500 rupaye') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.education));
        expect(((parseText('Course pe 2500 kharch hua') as VoiceParseSuccess).command as AddExpenseCommand).category, equals(ExpenseCategory.education));
      });
    });

    group('Unknown Category Handling', () {
      test('leaves category as null when no category words are present (never defaults to other)', () {
        final result = parseText('Spent 250');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, isNull);
      });

      test('parses "250 rupaye kharch kiye" with null category', () {
        final result = parseText('250 rupaye kharch kiye');
        expect(result, isA<VoiceParseSuccess>());
        final expenseCmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
        expect(expenseCmd.amountPaise, equals(25000));
        expect(expenseCmd.category, isNull);
      });
    });

    group('Amount Parsing Formats', () {
      test('parses integer rupees, decimal rupees, and paise correctly', () {
        expect(((parseText('Spent 250 on food') as VoiceParseSuccess).command as AddExpenseCommand).amountPaise, equals(25000));
        expect(((parseText('Spent 250.50 on food') as VoiceParseSuccess).command as AddExpenseCommand).amountPaise, equals(25050));
        expect(((parseText('Spent 250.5 on food') as VoiceParseSuccess).command as AddExpenseCommand).amountPaise, equals(25050));
        expect(((parseText('Spent ₹1,200 on shopping') as VoiceParseSuccess).command as AddExpenseCommand).amountPaise, equals(120000));
      });

      test('parses spoken word numbers into exact integer paise', () {
        expect(((parseText('Spent two hundred fifty on food') as VoiceParseSuccess).command as AddExpenseCommand).amountPaise, equals(25000));
        expect(((parseText('खाने पर दो सौ पचास रुपये खर्च किए') as VoiceParseSuccess).command as AddExpenseCommand).amountPaise, equals(25000));
        expect(((parseText('Auto ke paanch sau rupaye') as VoiceParseSuccess).command as AddExpenseCommand).amountPaise, equals(50000));
      });

      test('fails gracefully when amount is zero or absent', () {
        final result = parseText('Spent 0 on food');
        expect(result, isA<VoiceParseFailure>());
      });
    });

    group('Merchant vs Expense Disambiguation Precedence', () {
      test('"Sharma ki dukaan se doodh liya 60 ka" remains AddPurchaseCommand', () {
        final result = parseText('Sharma ki dukaan se doodh liya 60 ka');
        expect(result, isA<VoiceParseSuccess>());
        final cmd = (result as VoiceParseSuccess).command;
        expect(cmd, isA<AddPurchaseCommand>());
        final purchaseCmd = cmd as AddPurchaseCommand;
        expect(purchaseCmd.merchantName, equals('Sharma'));
        expect(purchaseCmd.totalAmountPaise, equals(6000));
      });

      test('"Gupta ko 500 de diye" remains SettleMerchantCommand / RecordSettlementCommand', () {
        final result = parseText('Gupta ko 500 de diye');
        expect(result, isA<VoiceParseSuccess>());
        final cmd = (result as VoiceParseSuccess).command;
        expect(cmd, isA<RecordSettlementCommand>());
        final settleCmd = cmd as RecordSettlementCommand;
        expect(settleCmd.merchantName, equals('Gupta'));
        expect(settleCmd.amountPaise, equals(50000));
      });

      test('"Sharma ki dukaan add karo" remains CreateMerchantCommand', () {
        final result = parseText('Sharma ki dukaan add karo');
        expect(result, isA<VoiceParseSuccess>());
        final cmd = (result as VoiceParseSuccess).command;
        expect(cmd, isA<CreateMerchantCommand>());
        final createCmd = cmd as CreateMerchantCommand;
        expect(createCmd.merchantName, equals('Sharma'));
      });

      test('"Food pe 250 kharch kiye" becomes AddExpenseCommand', () {
        final result = parseText('Food pe 250 kharch kiye');
        expect(result, isA<VoiceParseSuccess>());
        final cmd = (result as VoiceParseSuccess).command;
        expect(cmd, isA<AddExpenseCommand>());
        expect((cmd as AddExpenseCommand).amountPaise, equals(25000));
      });
    });
  });
}

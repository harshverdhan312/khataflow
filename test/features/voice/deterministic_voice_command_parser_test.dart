import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/voice/data/deterministic_voice_command_parser.dart';
import 'package:khata_flow/features/voice/domain/voice_command.dart';
import 'package:khata_flow/features/voice/domain/voice_command_parser.dart';
import 'package:khata_flow/features/voice/domain/voice_transcript.dart';

void main() {
  const parser = DeterministicVoiceCommandParser();

  VoiceTranscript makeTranscript(String text) {
    return VoiceTranscript(
      text: text,
      locale: 'en_IN',
      isFinal: true,
      capturedAt: DateTime.now(),
    );
  }

  group('DeterministicVoiceCommandParser - Purchase Commands', () {
    test('parses simple purchase: "Sharma se doodh 60 liya"', () {
      final result = parser.parse(makeTranscript('Sharma se doodh 60 liya'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddPurchaseCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.items.length, equals(1));
      expect(cmd.items.first.name, equals('Doodh'));
      expect(cmd.items.first.amountPaise, equals(6000));
      expect(cmd.totalAmountPaise, equals(6000));
    });

    test('parses multi-item Hinglish purchase: "Sharma ki dukaan se doodh 60 rupaye aur bread 40 rupaye ka liya"', () {
      final result = parser.parse(makeTranscript(
        'Sharma ki dukaan se doodh 60 rupaye aur bread 40 rupaye ka liya',
      ));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddPurchaseCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.items.length, equals(2));
      expect(cmd.items[0].name, equals('Doodh'));
      expect(cmd.items[0].amountPaise, equals(6000));
      expect(cmd.items[1].name, equals('Bread'));
      expect(cmd.items[1].amountPaise, equals(4000));
      expect(cmd.totalAmountPaise, equals(10000));
    });

    test('parses multi-item purchase: "Sharma se milk 60 aur bread 40 liya"', () {
      final result = parser.parse(makeTranscript('Sharma se milk 60 aur bread 40 liya'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddPurchaseCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.items.length, equals(2));
      expect(cmd.items[0].name, equals('Milk'));
      expect(cmd.items[0].amountPaise, equals(6000));
      expect(cmd.items[1].name, equals('Bread'));
      expect(cmd.items[1].amountPaise, equals(4000));
      expect(cmd.totalAmountPaise, equals(10000));
    });

    test('parses amount first purchase: "Sharma store se 60 ka doodh aur 40 ka bread liya"', () {
      final result = parser.parse(makeTranscript('Sharma store se 60 ka doodh aur 40 ka bread liya'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddPurchaseCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.items.length, equals(2));
      expect(cmd.items[0].amountPaise, equals(6000));
      expect(cmd.items[1].amountPaise, equals(4000));
      expect(cmd.totalAmountPaise, equals(10000));
    });

    test('parses groceries purchase: "Sharma se groceries 250 ki li"', () {
      final result = parser.parse(makeTranscript('Sharma se groceries 250 ki li'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddPurchaseCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.items.length, equals(1));
      expect(cmd.items.first.name, equals('Groceries'));
      expect(cmd.items.first.amountPaise, equals(25000));
      expect(cmd.totalAmountPaise, equals(25000));
    });

    test('parses English purchase: "Buy milk 60 from Sharma"', () {
      final result = parser.parse(makeTranscript('Buy milk 60 from Sharma'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddPurchaseCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.items.length, equals(1));
      expect(cmd.items.first.name, equals('Milk'));
      expect(cmd.items.first.amountPaise, equals(6000));
      expect(cmd.totalAmountPaise, equals(6000));
    });

    test('parses English purchase: "Add bread 40 from Sharma"', () {
      final result = parser.parse(makeTranscript('Add bread 40 from Sharma'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddPurchaseCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.items.length, equals(1));
      expect(cmd.items.first.name, equals('Bread'));
      expect(cmd.items.first.amountPaise, equals(4000));
      expect(cmd.totalAmountPaise, equals(4000));
    });
  });

  group('DeterministicVoiceCommandParser - Settlement Commands', () {
    test('parses Hinglish settlement: "Sharma ko 500 de diye"', () {
      final result = parser.parse(makeTranscript('Sharma ko 500 de diye'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as RecordSettlementCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.amountPaise, equals(50000));
      expect(cmd.paymentReference, isNull);
    });

    test('parses Hindi settlement: "Gupta ko 1000 rupaye chuka diya"', () {
      final result = parser.parse(makeTranscript('Gupta ko 1000 rupaye chuka diya'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as RecordSettlementCommand;
      expect(cmd.merchantName, equals('Gupta'));
      expect(cmd.amountPaise, equals(100000));
    });

    test('parses udhaar settlement: "Sharma ka 500 rupaye udhaar chuka diya"', () {
      final result = parser.parse(makeTranscript('Sharma ka 500 rupaye udhaar chuka diya'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as RecordSettlementCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.amountPaise, equals(50000));
    });

    test('parses English settlement: "Paid 500 to Sharma"', () {
      final result = parser.parse(makeTranscript('Paid 500 to Sharma'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as RecordSettlementCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.amountPaise, equals(50000));
    });

    test('parses English settlement: "Pay 500 to Sharma"', () {
      final result = parser.parse(makeTranscript('Pay 500 to Sharma'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as RecordSettlementCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.amountPaise, equals(50000));
    });

    test('parses English settlement: "Settle 500 with Sharma"', () {
      final result = parser.parse(makeTranscript('Settle 500 with Sharma'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as RecordSettlementCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.amountPaise, equals(50000));
    });

    test('parses settlement with payment reference: "Paid 500 to Sharma ref TXN9988"', () {
      final result = parser.parse(makeTranscript('Paid 500 to Sharma ref TXN9988'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as RecordSettlementCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.amountPaise, equals(50000));
      expect(cmd.paymentReference, equals('TXN9988'));
    });
  });

  group('DeterministicVoiceCommandParser - Monetary Value Parsing (Integer Paise)', () {
    test('parses decimal amount accurately: "Sharma se bread 40.50 liya"', () {
      final result = parser.parse(makeTranscript('Sharma se bread 40.50 liya'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddPurchaseCommand;
      expect(cmd.totalAmountPaise, equals(4050));
      expect(cmd.items.first.amountPaise, equals(4050));
    });

    test('parses amount with currency symbol: "Sharma se bread ₹60 liya"', () {
      final result = parser.parse(makeTranscript('Sharma se bread ₹60 liya'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddPurchaseCommand;
      expect(cmd.totalAmountPaise, equals(6000));
    });

    test('parses thousands with comma: "Sharma ko 1,000 rupaye de diye"', () {
      final result = parser.parse(makeTranscript('Sharma ko 1,000 rupaye de diye'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as RecordSettlementCommand;
      expect(cmd.amountPaise, equals(100000));
    });

    test('parses word amounts: sau, hazaar, fifty, hundred, thousand', () {
      final r1 = parser.parse(makeTranscript('Sharma se milk sau liya'));
      expect(r1, isA<VoiceParseSuccess>());
      expect(((r1 as VoiceParseSuccess).command as AddPurchaseCommand).totalAmountPaise, equals(10000));

      final r2 = parser.parse(makeTranscript('Sharma ko hazaar de diye'));
      expect(r2, isA<VoiceParseSuccess>());
      expect(((r2 as VoiceParseSuccess).command as RecordSettlementCommand).amountPaise, equals(100000));

      final r3 = parser.parse(makeTranscript('Sharma se bread fifty liya'));
      expect(r3, isA<VoiceParseSuccess>());
      expect(((r3 as VoiceParseSuccess).command as AddPurchaseCommand).totalAmountPaise, equals(5000));

      final r4 = parser.parse(makeTranscript('Paid hundred to Sharma'));
      expect(r4, isA<VoiceParseSuccess>());
      expect(((r4 as VoiceParseSuccess).command as RecordSettlementCommand).amountPaise, equals(10000));

      final r5 = parser.parse(makeTranscript('Paid thousand to Sharma'));
      expect(r5, isA<VoiceParseSuccess>());
      expect(((r5 as VoiceParseSuccess).command as RecordSettlementCommand).amountPaise, equals(100000));
    });
  });

  group('DeterministicVoiceCommandParser - Failure & Safety Validation', () {
    test('fails on empty transcript', () {
      final result = parser.parse(makeTranscript('   '));
      expect(result, isA<VoiceParseFailure>());
      expect((result as VoiceParseFailure).errorMessage, contains('empty'));
    });

    test('fails when merchant is missing in purchase', () {
      final result = parser.parse(makeTranscript('se doodh 60 liya'));
      expect(result, isA<VoiceParseFailure>());
    });

    test('fails when amount is missing in purchase', () {
      final result = parser.parse(makeTranscript('Sharma se doodh liya'));
      expect(result, isA<VoiceParseFailure>());
    });

    test('fails on conflicting spoken total: "Sharma se doodh 60 aur bread 40 total 120 liya"', () {
      final result = parser.parse(makeTranscript(
        'Sharma se doodh 60 aur bread 40 total 120 liya',
      ));
      expect(result, isA<VoiceParseFailure>());
      expect((result as VoiceParseFailure).errorMessage, contains('not match'));
    });

    test('succeeds when spoken total matches items: "Sharma se doodh 60 aur bread 40 total 100 liya"', () {
      final result = parser.parse(makeTranscript(
        'Sharma se doodh 60 aur bread 40 total 100 liya',
      ));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddPurchaseCommand;
      expect(cmd.totalAmountPaise, equals(10000));
    });

    test('fails on unsupported non-ledger sentence', () {
      final result = parser.parse(makeTranscript('Hello how is the weather today'));
      expect(result, isA<VoiceParseFailure>());
    });
  });

  group('DeterministicVoiceCommandParser - Full Settlement Commands (M5.4)', () {
    test('parses Hinglish full settlement: "Sharma ki payment settle kar do"', () {
      final result = parser.parse(makeTranscript('Sharma ki payment settle kar do'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command;
      expect(cmd, isA<SettleMerchantCommand>());
      expect((cmd as SettleMerchantCommand).merchantName, equals('Sharma'));
    });

    test('parses Hinglish full hisab settlement: "Sharma ka poora hisab settle kar do"', () {
      final result = parser.parse(makeTranscript('Sharma ka poora hisab settle kar do'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command;
      expect(cmd, isA<SettleMerchantCommand>());
      expect((cmd as SettleMerchantCommand).merchantName, equals('Sharma'));
    });

    test('parses Hindi full payment: "Sharma ki poori payment kar di"', () {
      final result = parser.parse(makeTranscript('Sharma ki poori payment kar di'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command;
      expect(cmd, isA<SettleMerchantCommand>());
      expect((cmd as SettleMerchantCommand).merchantName, equals('Sharma'));
    });

    test('parses English full settlement: "Settle Sharma"', () {
      final result = parser.parse(makeTranscript('Settle Sharma'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command;
      expect(cmd, isA<SettleMerchantCommand>());
      expect((cmd as SettleMerchantCommand).merchantName, equals('Sharma'));
    });

    test('parses English full settlement: "Settle full balance for Sharma General Store"', () {
      final result = parser.parse(makeTranscript('Settle full balance for Sharma General Store'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command;
      expect(cmd, isA<SettleMerchantCommand>());
      expect((cmd as SettleMerchantCommand).merchantName, equals('Sharma General Store'));
    });
  });

  group('DeterministicVoiceCommandParser - Create Merchant / Ledger Commands (M5.4)', () {
    test('parses grocery merchant creation: "Rahul sabji wale ka ledger bana do"', () {
      final result = parser.parse(makeTranscript('Rahul sabji wale ka ledger bana do'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command;
      expect(cmd, isA<CreateMerchantCommand>());
      final createCmd = cmd as CreateMerchantCommand;
      expect(createCmd.merchantName, equals('Rahul Sabji Wale'));
      expect(createCmd.category, equals(MerchantCategory.grocery));
      expect(createCmd.upiVpa, isNull);
    });

    test('parses milk merchant creation: "Verma doodh wale ka khata bana do"', () {
      final result = parser.parse(makeTranscript('Verma doodh wale ka khata bana do'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as CreateMerchantCommand;
      expect(cmd.merchantName, equals('Verma Doodh Wale'));
      expect(cmd.category, equals(MerchantCategory.milk));
    });

    test('parses laundry merchant creation: "Ravi Dhobi ka khata bana do"', () {
      final result = parser.parse(makeTranscript('Ravi Dhobi ka khata bana do'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as CreateMerchantCommand;
      expect(cmd.merchantName, equals('Ravi Dhobi'));
      expect(cmd.category, equals(MerchantCategory.laundry));
    });

    test('does NOT infer grocery from "shop" or "store": "Rahul ki mobile shop ka ledger bana do"', () {
      final result = parser.parse(makeTranscript('Rahul ki mobile shop ka ledger bana do'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as CreateMerchantCommand;
      expect(cmd.merchantName, equals('Rahul Ki Mobile Shop'));
      // Must be null (unknown), NOT grocery!
      expect(cmd.category, isNull);
    });

    test('parses merchant creation with VPA: "Ajay store ka khata bana do upi ajay@oksbi"', () {
      final result = parser.parse(makeTranscript('Ajay store ka khata bana do upi ajay@oksbi'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as CreateMerchantCommand;
      expect(cmd.merchantName, equals('Ajay Store'));
      expect(cmd.upiVpa, equals('ajay@oksbi'));
      expect(cmd.category, isNull);
    });

    test('parses English merchant creation: "Create ledger for Amit Dairy upi amit@paytm"', () {
      final result = parser.parse(makeTranscript('Create ledger for Amit Dairy upi amit@paytm'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as CreateMerchantCommand;
      expect(cmd.merchantName, equals('Amit Dairy'));
      expect(cmd.category, equals(MerchantCategory.milk));
      expect(cmd.upiVpa, equals('amit@paytm'));
    });
  });

  group('Cross-Command Architecture & First-Person Preservation Tests', () {
    test('Sharma ki dukaan se doodh liya 60 ka -> AddPurchaseCommand', () {
      final result = parser.parse(makeTranscript('Sharma ki dukaan se doodh liya 60 ka'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddPurchaseCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.totalAmountPaise, equals(6000));
    });

    test('Gupta ko 500 de diye -> RecordSettlementCommand', () {
      final result = parser.parse(makeTranscript('Gupta ko 500 de diye'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as RecordSettlementCommand;
      expect(cmd.merchantName, equals('Gupta'));
      expect(cmd.amountPaise, equals(50000));
    });

    test('Sharma ki dukaan add karo -> CreateMerchantCommand', () {
      final result = parser.parse(makeTranscript('Sharma ki dukaan add karo'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as CreateMerchantCommand;
      expect(cmd.merchantName, equals('Sharma'));
    });

    test('Food pe 250 kharch kiye -> AddExpenseCommand', () {
      final result = parser.parse(makeTranscript('Food pe 250 kharch kiye'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
      expect(cmd.amountPaise, equals(25000));
      expect(cmd.category, equals(ExpenseCategory.food));
    });

    test('Spent 250 rupees on food -> AddExpenseCommand', () {
      final result = parser.parse(makeTranscript('Spent 250 rupees on food'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
      expect(cmd.amountPaise, equals(25000));
      expect(cmd.category, equals(ExpenseCategory.food));
    });

    test('I spent 250 rupees on food -> AddExpenseCommand', () {
      final result = parser.parse(makeTranscript('I spent 250 rupees on food'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
      expect(cmd.amountPaise, equals(25000));
      expect(cmd.category, equals(ExpenseCategory.food));
    });

    test('I paid 500 to Sharma -> RecordSettlementCommand', () {
      final result = parser.parse(makeTranscript('I paid 500 to Sharma'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as RecordSettlementCommand;
      expect(cmd.merchantName, equals('Sharma'));
      expect(cmd.amountPaise, equals(50000));
    });

    test('I paid 250 rupees for food -> AddExpenseCommand', () {
      final result = parser.parse(makeTranscript('I paid 250 rupees for food'));
      expect(result, isA<VoiceParseSuccess>());
      final cmd = (result as VoiceParseSuccess).command as AddExpenseCommand;
      expect(cmd.amountPaise, equals(25000));
      expect(cmd.category, equals(ExpenseCategory.food));
    });
  });
}

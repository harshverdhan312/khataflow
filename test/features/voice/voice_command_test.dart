import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/voice/domain/voice_command.dart';

void main() {
  group('VoiceCommand Domain Models', () {
    group('AddPurchaseCommand', () {
      test('creates valid command with multiple items and integer paise totals', () {
        const item1 = VoicePurchaseItem(name: 'Milk', amountPaise: 6000); // ₹60.00
        const item2 = VoicePurchaseItem(name: 'Bread', amountPaise: 4000); // ₹40.00

        const command = AddPurchaseCommand(
          merchantName: 'Sharma General Store',
          items: [item1, item2],
          totalAmountPaise: 10000, // ₹100.00
        );

        expect(command.merchantName, equals('Sharma General Store'));
        expect(command.items.length, equals(2));
        expect(command.items[0].name, equals('Milk'));
        expect(command.items[0].amountPaise, equals(6000));
        expect(command.items[1].name, equals('Bread'));
        expect(command.items[1].amountPaise, equals(4000));
        expect(command.totalAmountPaise, equals(10000));
        expect(command, isA<VoiceCommand>());
      });

      test('equality and hashCode match identical AddPurchaseCommand instances', () {
        const cmd1 = AddPurchaseCommand(
          merchantName: 'Gupta Kirana',
          items: [VoicePurchaseItem(name: 'Rice 5kg', amountPaise: 25000)],
          totalAmountPaise: 25000,
        );
        const cmd2 = AddPurchaseCommand(
          merchantName: 'Gupta Kirana',
          items: [VoicePurchaseItem(name: 'Rice 5kg', amountPaise: 25000)],
          totalAmountPaise: 25000,
        );
        const cmd3 = AddPurchaseCommand(
          merchantName: 'Gupta Kirana',
          items: [VoicePurchaseItem(name: 'Wheat 5kg', amountPaise: 25000)],
          totalAmountPaise: 25000,
        );

        expect(cmd1, equals(cmd2));
        expect(cmd1.hashCode, equals(cmd2.hashCode));
        expect(cmd1, isNot(equals(cmd3)));
      });
    });

    group('RecordSettlementCommand', () {
      test('creates valid command with integer paise and optional payment reference', () {
        const command = RecordSettlementCommand(
          merchantName: 'Sharma General Store',
          amountPaise: 50000, // ₹500.00
          paymentReference: 'UPI-REF-123456',
        );

        expect(command.merchantName, equals('Sharma General Store'));
        expect(command.amountPaise, equals(50000));
        expect(command.paymentReference, equals('UPI-REF-123456'));
        expect(command, isA<VoiceCommand>());
      });

      test('creates valid command without payment reference', () {
        const command = RecordSettlementCommand(
          merchantName: 'Sharma General Store',
          amountPaise: 50000,
          paymentReference: null,
        );

        expect(command.merchantName, equals('Sharma General Store'));
        expect(command.amountPaise, equals(50000));
        expect(command.paymentReference, isNull);
      });

      test('equality and hashCode match identical RecordSettlementCommand instances', () {
        const cmd1 = RecordSettlementCommand(
          merchantName: 'Sharma Sweets',
          amountPaise: 30000,
          paymentReference: 'REF123',
        );
        const cmd2 = RecordSettlementCommand(
          merchantName: 'Sharma Sweets',
          amountPaise: 30000,
          paymentReference: 'REF123',
        );
        const cmd3 = RecordSettlementCommand(
          merchantName: 'Sharma Sweets',
          amountPaise: 30000,
          paymentReference: null,
        );

        expect(cmd1, equals(cmd2));
        expect(cmd1.hashCode, equals(cmd2.hashCode));
        expect(cmd1, isNot(equals(cmd3)));
      });
    });

    group('SettleMerchantCommand', () {
      test('creates valid command with merchant name', () {
        const command = SettleMerchantCommand(
          merchantName: 'Sharma General Store',
        );

        expect(command.merchantName, equals('Sharma General Store'));
        expect(command, isA<VoiceCommand>());
      });

      test('equality and hashCode match identical SettleMerchantCommand instances', () {
        const cmd1 = SettleMerchantCommand(merchantName: 'Sharma General Store');
        const cmd2 = SettleMerchantCommand(merchantName: 'Sharma General Store');
        const cmd3 = SettleMerchantCommand(merchantName: 'Verma Dairy');

        expect(cmd1, equals(cmd2));
        expect(cmd1.hashCode, equals(cmd2.hashCode));
        expect(cmd1, isNot(equals(cmd3)));
      });
    });

    group('CreateMerchantCommand', () {
      test('creates valid command with optional category and upiVpa', () {
        const command = CreateMerchantCommand(
          merchantName: 'Rahul Sabji Wala',
          category: null,
          upiVpa: 'rahul@oksbi',
        );

        expect(command.merchantName, equals('Rahul Sabji Wala'));
        expect(command.category, isNull);
        expect(command.upiVpa, equals('rahul@oksbi'));
        expect(command, isA<VoiceCommand>());
      });

      test('equality and hashCode match identical CreateMerchantCommand instances', () {
        const cmd1 = CreateMerchantCommand(
          merchantName: 'Rahul Sabji Wala',
          upiVpa: 'rahul@oksbi',
        );
        const cmd2 = CreateMerchantCommand(
          merchantName: 'Rahul Sabji Wala',
          upiVpa: 'rahul@oksbi',
        );
        const cmd3 = CreateMerchantCommand(
          merchantName: 'Rahul Sabji Wala',
          upiVpa: null,
        );

        expect(cmd1, equals(cmd2));
        expect(cmd1.hashCode, equals(cmd2.hashCode));
        expect(cmd1, isNot(equals(cmd3)));
      });
    });

    group('AddExpenseCommand', () {
      final testDate = DateTime(2026, 9, 17);

      test('creates valid command with integer paise, category, and note', () {
        final command = AddExpenseCommand(
          amountPaise: 25000,
          category: ExpenseCategory.food,
          note: 'lunch with friends',
          expenseDate: testDate,
        );

        expect(command.amountPaise, equals(25000));
        expect(command.category, equals(ExpenseCategory.food));
        expect(command.note, equals('lunch with friends'));
        expect(command.expenseDate, equals(testDate));
        expect(command, isA<VoiceCommand>());
      });

      test('allows nullable category and nullable note', () {
        final command = AddExpenseCommand(
          amountPaise: 50000,
          category: null,
          note: null,
          expenseDate: testDate,
        );

        expect(command.amountPaise, equals(50000));
        expect(command.category, isNull);
        expect(command.note, isNull);
      });

      test('equality and hashCode match identical AddExpenseCommand instances', () {
        final cmd1 = AddExpenseCommand(
          amountPaise: 25000,
          category: ExpenseCategory.transport,
          note: 'auto',
          expenseDate: testDate,
        );
        final cmd2 = AddExpenseCommand(
          amountPaise: 25000,
          category: ExpenseCategory.transport,
          note: 'auto',
          expenseDate: testDate,
        );
        final cmd3 = AddExpenseCommand(
          amountPaise: 30000,
          category: ExpenseCategory.transport,
          note: 'auto',
          expenseDate: testDate,
        );

        expect(cmd1, equals(cmd2));
        expect(cmd1.hashCode, equals(cmd2.hashCode));
        expect(cmd1, isNot(equals(cmd3)));
      });
    });
  });
}

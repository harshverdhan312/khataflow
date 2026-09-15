import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/features/settlement/domain/settlement_status.dart';

void main() {
  group('SettlementStatus State Machine', () {
    test('converts each enum value to correct DB string value', () {
      expect(SettlementStatus.initiated.toDbValue(), equals('INITIATED'));
      expect(SettlementStatus.settled.toDbValue(), equals('SETTLED'));
      expect(SettlementStatus.failed.toDbValue(), equals('FAILED'));
      expect(SettlementStatus.unknown.toDbValue(), equals('UNKNOWN'));
    });

    test('parses DB string values correctly, mapping legacy UPI_LAUNCHED to UNKNOWN', () {
      expect(SettlementStatus.fromDbValue('INITIATED'), equals(SettlementStatus.initiated));
      expect(SettlementStatus.fromDbValue('UPI_LAUNCHED'), equals(SettlementStatus.unknown));
      expect(SettlementStatus.fromDbValue('SETTLED'), equals(SettlementStatus.settled));
      expect(SettlementStatus.fromDbValue('SUCCESS'), equals(SettlementStatus.settled));
      expect(SettlementStatus.fromDbValue('FAILED'), equals(SettlementStatus.failed));
      expect(SettlementStatus.fromDbValue('UNKNOWN'), equals(SettlementStatus.unknown));
      expect(SettlementStatus.fromDbValue('UNRECOGNIZED'), equals(SettlementStatus.unknown));
    });

    test('correctly identifies terminal states', () {
      expect(SettlementStatus.settled.isTerminal, isTrue);
      expect(SettlementStatus.failed.isTerminal, isTrue);
      expect(SettlementStatus.initiated.isTerminal, isFalse);
      expect(SettlementStatus.unknown.isTerminal, isFalse);
    });

    test('correctly identifies unresolved states', () {
      expect(SettlementStatus.initiated.isUnresolved, isTrue);
      expect(SettlementStatus.unknown.isUnresolved, isTrue);
      expect(SettlementStatus.settled.isUnresolved, isFalse);
      expect(SettlementStatus.failed.isUnresolved, isFalse);
    });

    test('correctly identifies settled status', () {
      expect(SettlementStatus.settled.isSettled, isTrue);
      expect(SettlementStatus.initiated.isSettled, isFalse);
      expect(SettlementStatus.failed.isSettled, isFalse);
      expect(SettlementStatus.unknown.isSettled, isFalse);
    });
  });
}

import 'package:flutter/foundation.dart';
import '../../expense/domain/expense_category.dart';
import '../../merchant/domain/merchant_category.dart';

/// Single item within an [AddPurchaseCommand].
@immutable
class VoicePurchaseItem {
  final String name;
  final int amountPaise;

  const VoicePurchaseItem({
    required this.name,
    required this.amountPaise,
  }) : assert(amountPaise >= 0, 'Item amount in paise must be non-negative');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoicePurchaseItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          amountPaise == other.amountPaise;

  @override
  int get hashCode => name.hashCode ^ amountPaise.hashCode;

  @override
  String toString() => 'VoicePurchaseItem(name: "$name", amountPaise: $amountPaise)';
}

/// Base sealed class representing a structured voice command to be produced by extractors.
sealed class VoiceCommand {
  const VoiceCommand();
}

/// Command representing an intention to add a purchase to a merchant's ledger.
@immutable
class AddPurchaseCommand extends VoiceCommand {
  final String merchantName;
  final List<VoicePurchaseItem> items;
  final int totalAmountPaise;

  const AddPurchaseCommand({
    required this.merchantName,
    required this.items,
    required this.totalAmountPaise,
  }) : assert(totalAmountPaise >= 0, 'Total amount in paise must be non-negative');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddPurchaseCommand &&
          runtimeType == other.runtimeType &&
          merchantName == other.merchantName &&
          listEquals(items, other.items) &&
          totalAmountPaise == other.totalAmountPaise;

  @override
  int get hashCode =>
      merchantName.hashCode ^ Object.hashAll(items) ^ totalAmountPaise.hashCode;

  @override
  String toString() =>
      'AddPurchaseCommand(merchantName: "$merchantName", items: $items, totalAmountPaise: $totalAmountPaise)';
}

/// Command representing an intention to record a manual settlement for a specific amount.
@immutable
class RecordSettlementCommand extends VoiceCommand {
  final String merchantName;
  final int amountPaise;
  final String? paymentReference;

  const RecordSettlementCommand({
    required this.merchantName,
    required this.amountPaise,
    this.paymentReference,
  }) : assert(amountPaise > 0, 'Settlement amount in paise must be positive');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordSettlementCommand &&
          runtimeType == other.runtimeType &&
          merchantName == other.merchantName &&
          amountPaise == other.amountPaise &&
          paymentReference == other.paymentReference;

  @override
  int get hashCode =>
      merchantName.hashCode ^ amountPaise.hashCode ^ paymentReference.hashCode;

  @override
  String toString() =>
      'RecordSettlementCommand(merchantName: "$merchantName", amountPaise: $amountPaise, paymentReference: $paymentReference)';
}

/// Command representing an intention to settle a merchant's full current outstanding balance.
///
/// NOTE: Does not contain an amount from speech because the amount is derived from
/// the merchant's current live ledger balance in SQLite.
@immutable
class SettleMerchantCommand extends VoiceCommand {
  final String merchantName;

  const SettleMerchantCommand({
    required this.merchantName,
  }) : assert(merchantName.length > 0, 'Merchant name must not be empty');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettleMerchantCommand &&
          runtimeType == other.runtimeType &&
          merchantName == other.merchantName;

  @override
  int get hashCode => merchantName.hashCode;

  @override
  String toString() => 'SettleMerchantCommand(merchantName: "$merchantName")';
}

/// Command representing an intention to create a new merchant ledger.
@immutable
class CreateMerchantCommand extends VoiceCommand {
  final String merchantName;
  final MerchantCategory? category;
  final String? upiVpa;

  const CreateMerchantCommand({
    required this.merchantName,
    this.category,
    this.upiVpa,
  }) : assert(merchantName.length > 0, 'Merchant name must not be empty');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateMerchantCommand &&
          runtimeType == other.runtimeType &&
          merchantName == other.merchantName &&
          category == other.category &&
          upiVpa == other.upiVpa;

  @override
  int get hashCode => merchantName.hashCode ^ category.hashCode ^ upiVpa.hashCode;

  @override
  String toString() =>
      'CreateMerchantCommand(merchantName: "$merchantName", category: $category, upiVpa: $upiVpa)';
}

/// Command representing an intention to record a personal expense.
@immutable
class AddExpenseCommand extends VoiceCommand {
  final int amountPaise;
  final ExpenseCategory? category;
  final String? note;
  final DateTime expenseDate;

  const AddExpenseCommand({
    required this.amountPaise,
    this.category,
    this.note,
    required this.expenseDate,
  }) : assert(amountPaise > 0, 'Expense amount in paise must be positive');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddExpenseCommand &&
          runtimeType == other.runtimeType &&
          amountPaise == other.amountPaise &&
          category == other.category &&
          note == other.note &&
          expenseDate == other.expenseDate;

  @override
  int get hashCode =>
      amountPaise.hashCode ^
      category.hashCode ^
      note.hashCode ^
      expenseDate.hashCode;

  @override
  String toString() =>
      'AddExpenseCommand(amountPaise: $amountPaise, category: $category, note: "$note", expenseDate: $expenseDate)';
}


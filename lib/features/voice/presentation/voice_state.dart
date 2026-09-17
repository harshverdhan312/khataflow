import 'package:flutter/foundation.dart';
import '../../expense/domain/expense_category.dart';
import '../../merchant/domain/merchant.dart';
import '../../merchant/domain/merchant_category.dart';
import '../domain/semantic_voice_interpretation.dart';
import '../domain/voice_command.dart';
import '../domain/voice_transcript.dart';

/// Lifecycle statuses of voice ledger recognition and extraction.
enum VoiceStatus {
  idle,
  listening,
  processing,
  ambiguousMerchant,
  commandReady,
  completed,
  error,
}

/// State representation for voice ledger interaction, parsing, and execution.
@immutable
class VoiceState {
  final VoiceStatus status;
  final VoiceTranscript? transcript;
  final VoiceCommand? command;
  final Merchant? resolvedMerchant;
  final List<Merchant>? candidateMerchants;
  final String? errorMessage;
  final String selectedLocale;
  final bool isExecuting;
  final int? outstandingPaiseToSettle;
  final MerchantCategory? pendingCategory;
  final ExpenseCategory? pendingExpenseCategory;
  final String? pendingUpiVpa;
  final String? pendingPaymentReference;
  final SemanticVoiceInterpretation? pendingInterpretation;

  const VoiceState({
    this.status = VoiceStatus.idle,
    this.transcript,
    this.command,
    this.resolvedMerchant,
    this.candidateMerchants,
    this.errorMessage,
    this.selectedLocale = 'en_IN',
    this.isExecuting = false,
    this.outstandingPaiseToSettle,
    this.pendingCategory,
    this.pendingExpenseCategory,
    this.pendingUpiVpa,
    this.pendingPaymentReference,
    this.pendingInterpretation,
  });

  bool get isListening => status == VoiceStatus.listening;
  bool get isProcessing => status == VoiceStatus.processing;
  bool get isAmbiguousMerchant => status == VoiceStatus.ambiguousMerchant;
  bool get isCommandReady => status == VoiceStatus.commandReady;
  bool get isCompleted => status == VoiceStatus.completed;
  bool get hasError => status == VoiceStatus.error;

  VoiceState copyWith({
    VoiceStatus? status,
    VoiceTranscript? transcript,
    VoiceCommand? command,
    Merchant? resolvedMerchant,
    List<Merchant>? candidateMerchants,
    String? errorMessage,
    String? selectedLocale,
    bool? isExecuting,
    int? outstandingPaiseToSettle,
    MerchantCategory? pendingCategory,
    ExpenseCategory? pendingExpenseCategory,
    String? pendingUpiVpa,
    String? pendingPaymentReference,
    SemanticVoiceInterpretation? pendingInterpretation,
    bool clearTranscript = false,
    bool clearCommand = false,
    bool clearMerchant = false,
    bool clearCandidates = false,
    bool clearError = false,
    bool clearOutstanding = false,
    bool clearPendingCategory = false,
    bool clearPendingExpenseCategory = false,
    bool clearPendingVpa = false,
    bool clearPendingPaymentRef = false,
    bool clearPendingInterpretation = false,
  }) {
    return VoiceState(
      status: status ?? this.status,
      transcript: clearTranscript ? null : (transcript ?? this.transcript),
      command: clearCommand ? null : (command ?? this.command),
      resolvedMerchant:
          clearMerchant ? null : (resolvedMerchant ?? this.resolvedMerchant),
      candidateMerchants: clearCandidates
          ? null
          : (candidateMerchants ?? this.candidateMerchants),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedLocale: selectedLocale ?? this.selectedLocale,
      isExecuting: isExecuting ?? this.isExecuting,
      outstandingPaiseToSettle: clearOutstanding
          ? null
          : (outstandingPaiseToSettle ?? this.outstandingPaiseToSettle),
      pendingCategory: clearPendingCategory
          ? null
          : (pendingCategory ?? this.pendingCategory),
      pendingExpenseCategory: clearPendingExpenseCategory
          ? null
          : (pendingExpenseCategory ?? this.pendingExpenseCategory),
      pendingUpiVpa:
          clearPendingVpa ? null : (pendingUpiVpa ?? this.pendingUpiVpa),
      pendingPaymentReference: clearPendingPaymentRef
          ? null
          : (pendingPaymentReference ?? this.pendingPaymentReference),
      pendingInterpretation: clearPendingInterpretation
          ? null
          : (pendingInterpretation ?? this.pendingInterpretation),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          transcript == other.transcript &&
          command == other.command &&
          resolvedMerchant == other.resolvedMerchant &&
          listEquals(candidateMerchants, other.candidateMerchants) &&
          errorMessage == other.errorMessage &&
          selectedLocale == other.selectedLocale &&
          isExecuting == other.isExecuting &&
          outstandingPaiseToSettle == other.outstandingPaiseToSettle &&
          pendingCategory == other.pendingCategory &&
          pendingExpenseCategory == other.pendingExpenseCategory &&
          pendingUpiVpa == other.pendingUpiVpa &&
          pendingPaymentReference == other.pendingPaymentReference &&
          pendingInterpretation == other.pendingInterpretation;

  @override
  int get hashCode =>
      status.hashCode ^
      transcript.hashCode ^
      command.hashCode ^
      resolvedMerchant.hashCode ^
      (candidateMerchants != null ? Object.hashAll(candidateMerchants!) : 0) ^
      errorMessage.hashCode ^
      selectedLocale.hashCode ^
      isExecuting.hashCode ^
      outstandingPaiseToSettle.hashCode ^
      pendingCategory.hashCode ^
      pendingExpenseCategory.hashCode ^
      pendingUpiVpa.hashCode ^
      pendingPaymentReference.hashCode ^
      pendingInterpretation.hashCode;

  @override
  String toString() =>
      'VoiceState(status: $status, transcript: $transcript, command: $command, resolvedMerchant: ${resolvedMerchant?.name}, candidateMerchants: ${candidateMerchants?.map((c) => c.name).toList()}, errorMessage: $errorMessage, selectedLocale: $selectedLocale, isExecuting: $isExecuting, outstanding: $outstandingPaiseToSettle, pendingCategory: $pendingCategory, pendingExpenseCategory: $pendingExpenseCategory, pendingVpa: $pendingUpiVpa, pendingRef: $pendingPaymentReference, pendingInterpretation: $pendingInterpretation)';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/utils/validators.dart';
import '../../expense/domain/expense.dart';
import '../../expense/domain/expense_category.dart';
import '../../expense/domain/expense_repository.dart';
import '../../ledger/domain/ledger_repository.dart';
import '../../ledger/domain/purchase.dart';
import '../../merchant/domain/merchant.dart';
import '../../merchant/domain/merchant_category.dart';
import '../../merchant/domain/merchant_repository.dart';
import '../../settlement/domain/settlement_repository.dart';
import '../domain/merchant_resolver.dart';
import '../domain/voice_command.dart';
import '../domain/voice_command_parser.dart';
import '../domain/voice_transcript.dart';
import 'voice_state.dart';

/// Controller managing speech recognition interaction, parsing,
/// merchant resolution, and confirmed ledger command execution.
///
/// NOTE: Follows architectural rule of having NO BuildContext in the controller.
class VoiceController extends StateNotifier<VoiceState> {
  final VoiceService voiceService;
  final VoiceCommandParser parser;
  final MerchantRepository merchantRepository;
  final LedgerRepository ledgerRepository;
  final SettlementRepository settlementRepository;
  final ExpenseRepository expenseRepository;
  final MerchantResolver merchantResolver;

  VoiceController({
    required this.voiceService,
    required this.parser,
    required this.merchantRepository,
    required this.ledgerRepository,
    required this.settlementRepository,
    required this.expenseRepository,
    this.merchantResolver = const MerchantResolver(),
  }) : super(const VoiceState());

  /// Starts listening to microphone input in the currently selected locale.
  Future<void> startListening() async {
    // Clear previous state and reset for fresh voice session
    state = state.copyWith(
      status: VoiceStatus.listening,
      clearError: true,
      clearTranscript: true,
      clearCommand: true,
      clearMerchant: true,
      clearCandidates: true,
      clearOutstanding: true,
      clearPendingCategory: true,
      clearPendingExpenseCategory: true,
      clearPendingVpa: true,
      clearPendingPaymentRef: true,
    );

    try {
      final initialized = await voiceService.initialize();
      if (!initialized) {
        state = state.copyWith(
          status: VoiceStatus.error,
          errorMessage: 'Microphone permission is required to use Voice Ledger.',
        );
        return;
      }

      await voiceService.startListening(
        localeId: state.selectedLocale,
        onResult: (text, isFinal) {
          final transcript = VoiceTranscript(
            text: text,
            locale: state.selectedLocale,
            isFinal: isFinal,
            capturedAt: DateTime.now(),
          );

          if (isFinal) {
            processTranscript(transcript);
          } else {
            // Partial transcripts are UI-only (never parsed)
            state = state.copyWith(
              status: VoiceStatus.listening,
              transcript: transcript,
            );
          }
        },
        onError: (error) {
          state = state.copyWith(
            status: VoiceStatus.error,
            errorMessage: error,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Stops listening and processes the final transcript.
  Future<void> stopListening() async {
    try {
      await voiceService.stopListening();
    } catch (_) {}

    if (state.transcript != null && state.transcript!.text.trim().isNotEmpty) {
      final finalTranscript = state.transcript!.copyWith(isFinal: true);
      await processTranscript(finalTranscript);
    } else {
      state = state.copyWith(status: VoiceStatus.idle);
    }
  }

  /// Cancels listening and discards any active transcript.
  Future<void> cancelListening() async {
    try {
      await voiceService.cancelListening();
    } catch (_) {}

    state = state.copyWith(
      status: VoiceStatus.idle,
      clearTranscript: true,
      clearCommand: true,
      clearMerchant: true,
      clearCandidates: true,
      clearError: true,
      clearOutstanding: true,
      clearPendingCategory: true,
      clearPendingExpenseCategory: true,
      clearPendingVpa: true,
      clearPendingPaymentRef: true,
    );
  }

  /// Processes the final transcript through the parser and merchant resolver.
  Future<void> processTranscript(VoiceTranscript transcript) async {
    state = state.copyWith(
      status: VoiceStatus.processing,
      transcript: transcript,
      clearError: true,
      clearCommand: true,
      clearMerchant: true,
      clearCandidates: true,
      clearOutstanding: true,
      clearPendingCategory: true,
      clearPendingExpenseCategory: true,
      clearPendingVpa: true,
      clearPendingPaymentRef: true,
    );

    // 1. Deterministic Parse
    final parseResult = parser.parse(transcript);
    if (parseResult is VoiceParseFailure) {
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: parseResult.errorMessage,
      );
      return;
    }

    final command = (parseResult as VoiceParseSuccess).command;

    // 2. AddExpenseCommand requires no merchant resolution
    if (command is AddExpenseCommand) {
      state = state.copyWith(
        status: VoiceStatus.commandReady,
        command: command,
        pendingExpenseCategory: command.category,
        clearMerchant: true,
        clearCandidates: true,
        clearError: true,
      );
      return;
    }

    // 3. Merchant Resolution based on command type
    try {
      final activeMerchants = await merchantRepository.getActiveMerchants();

      if (command is CreateMerchantCommand) {
        // Look up active merchants to prevent duplicate creation
        final resolution = merchantResolver.resolve(
          query: command.merchantName,
          activeMerchants: activeMerchants,
        );

        switch (resolution) {
          case ExactMerchantMatch(:final merchant):
            state = state.copyWith(
              status: VoiceStatus.error,
              command: command,
              clearMerchant: true,
              clearCandidates: true,
              errorMessage: 'Merchant "${merchant.name}" already exists.',
            );
          case AmbiguousMerchantMatch(:final candidates):
            state = state.copyWith(
              status: VoiceStatus.ambiguousMerchant,
              command: command,
              candidateMerchants: candidates,
              clearMerchant: true,
              clearError: true,
            );
          case NoMerchantMatch():
            state = state.copyWith(
              status: VoiceStatus.commandReady,
              command: command,
              pendingCategory: command.category,
              pendingUpiVpa: command.upiVpa,
              clearMerchant: true,
              clearCandidates: true,
              clearError: true,
            );
        }
        return;
      }

      // Existing commands (AddPurchaseCommand, RecordSettlementCommand, SettleMerchantCommand)
      final String merchantQuery = switch (command) {
        AddPurchaseCommand(:final merchantName) => merchantName,
        RecordSettlementCommand(:final merchantName) => merchantName,
        SettleMerchantCommand(:final merchantName) => merchantName,
        CreateMerchantCommand() => '',
        AddExpenseCommand() => '',
      };

      final resolution = merchantResolver.resolve(
        query: merchantQuery,
        activeMerchants: activeMerchants,
      );

      switch (resolution) {
        case ExactMerchantMatch(:final merchant):
          int? liveOutstanding;
          if (command is SettleMerchantCommand) {
            liveOutstanding = await ledgerRepository.getOutstandingAmount(merchant.id);
          }
          state = state.copyWith(
            status: VoiceStatus.commandReady,
            command: command,
            resolvedMerchant: merchant,
            outstandingPaiseToSettle: liveOutstanding,
            clearCandidates: true,
            clearError: true,
          );
        case AmbiguousMerchantMatch(:final candidates):
          state = state.copyWith(
            status: VoiceStatus.ambiguousMerchant,
            command: command,
            candidateMerchants: candidates,
            clearMerchant: true,
            clearError: true,
          );
        case NoMerchantMatch(:final query):
          state = state.copyWith(
            status: VoiceStatus.error,
            command: command,
            clearMerchant: true,
            clearCandidates: true,
            errorMessage: 'Merchant "$query" not found. We couldn\'t find a matching active store.',
          );
      }
    } catch (e) {
      state = state.copyWith(
        status: VoiceStatus.error,
        errorMessage: 'Failed to resolve merchant: ${e.toString()}',
      );
    }
  }

  /// Selects a candidate merchant when multiple stores matched the query.
  Future<void> selectCandidateMerchant(Merchant merchant) async {
    if (state.status != VoiceStatus.ambiguousMerchant || state.command == null) {
      return;
    }

    // If user was creating a merchant and picked an existing merchant candidate,
    // prevent duplicate creation and inform the user.
    if (state.command is CreateMerchantCommand) {
      state = state.copyWith(
        status: VoiceStatus.error,
        clearCandidates: true,
        errorMessage: 'Merchant "${merchant.name}" already exists.',
      );
      return;
    }

    int? liveOutstanding;
    if (state.command is SettleMerchantCommand) {
      liveOutstanding = await ledgerRepository.getOutstandingAmount(merchant.id);
    }

    state = state.copyWith(
      status: VoiceStatus.commandReady,
      resolvedMerchant: merchant,
      outstandingPaiseToSettle: liveOutstanding,
      clearCandidates: true,
      clearError: true,
    );
  }

  /// Updates the pending category for merchant creation confirmation.
  void setPendingCategory(MerchantCategory category) {
    state = state.copyWith(pendingCategory: category);
  }

  /// Updates the pending expense category for expense confirmation.
  void setPendingExpenseCategory(ExpenseCategory category) {
    state = state.copyWith(pendingExpenseCategory: category);
  }

  /// Updates the pending UPI VPA for merchant creation confirmation.
  void setPendingUpiVpa(String? vpa) {
    state = state.copyWith(pendingUpiVpa: vpa);
  }

  /// Updates the pending payment reference for settlement confirmation.
  void setPendingPaymentReference(String? reference) {
    state = state.copyWith(pendingPaymentReference: reference);
  }

  /// Cancels the current command without mutating the database and returns to idle.
  void cancelCommand() {
    state = state.copyWith(
      status: VoiceStatus.idle,
      clearCommand: true,
      clearMerchant: true,
      clearCandidates: true,
      clearTranscript: true,
      clearError: true,
      clearOutstanding: true,
      clearPendingCategory: true,
      clearPendingExpenseCategory: true,
      clearPendingVpa: true,
      clearPendingPaymentRef: true,
    );
  }

  /// Executes the confirmed command using existing repositories.
  ///
  /// CRITICAL: Only invoked upon explicit user confirmation.
  /// Never called silently. Contains NO BuildContext.
  Future<bool> executeConfirmedCommand() async {
    if (state.status != VoiceStatus.commandReady ||
        state.command == null ||
        state.isExecuting) {
      return false;
    }

    state = state.copyWith(isExecuting: true, clearError: true);

    try {
      final command = state.command!;

      if (command is AddPurchaseCommand) {
        if (state.resolvedMerchant == null) return false;
        final merchant = state.resolvedMerchant!;

        for (final item in command.items) {
          await ledgerRepository.addPurchase(
            CreatePurchaseInput(
              merchantId: merchant.id,
              amountPaise: item.amountPaise,
              note: item.name,
              purchaseDate: DateTime.now(),
            ),
          );
        }
      } else if (command is RecordSettlementCommand) {
        if (state.resolvedMerchant == null) return false;
        final merchant = state.resolvedMerchant!;

        final unsettled = await ledgerRepository.getUnsettledPurchases(merchant.id);
        if (unsettled.isEmpty) {
          state = state.copyWith(
            isExecuting: false,
            status: VoiceStatus.error,
            errorMessage: 'No unsettled dues found for ${merchant.name}.',
          );
          return false;
        }

        final purchaseIds = unsettled.map((p) => p.id).toList();
        await settlementRepository.recordSettlement(
          merchantId: merchant.id,
          purchaseIds: purchaseIds,
          paymentReference: state.pendingPaymentReference ?? command.paymentReference,
        );
      } else if (command is SettleMerchantCommand) {
        if (state.resolvedMerchant == null) return false;
        final merchant = state.resolvedMerchant!;

        // Race condition protection: Re-read live outstanding & unsettled purchases
        final liveOutstanding = await ledgerRepository.getOutstandingAmount(merchant.id);
        final unsettled = await ledgerRepository.getUnsettledPurchases(merchant.id);

        if (unsettled.isEmpty || liveOutstanding <= 0) {
          state = state.copyWith(
            isExecuting: false,
            status: VoiceStatus.error,
            errorMessage: 'No outstanding dues found for ${merchant.name}.',
          );
          return false;
        }

        final purchaseIds = unsettled.map((p) => p.id).toList();
        await settlementRepository.recordSettlement(
          merchantId: merchant.id,
          purchaseIds: purchaseIds,
          paymentReference: state.pendingPaymentReference,
        );
      } else if (command is CreateMerchantCommand) {
        if (state.pendingCategory == null) {
          state = state.copyWith(
            isExecuting: false,
            status: VoiceStatus.error,
            errorMessage: 'Please select a category for the merchant.',
          );
          return false;
        }

        final vpa = state.pendingUpiVpa?.trim() ?? '';
        if (vpa.isNotEmpty) {
          final vpaError = Validators.validateUpiVpa(vpa, isOptional: false);
          if (vpaError != null) {
            state = state.copyWith(
              isExecuting: false,
              status: VoiceStatus.error,
              errorMessage: vpaError,
            );
            return false;
          }
        }

        // Final check for duplicate active merchant
        final activeMerchants = await merchantRepository.getActiveMerchants();
        final resolution = merchantResolver.resolve(
          query: command.merchantName,
          activeMerchants: activeMerchants,
        );
        if (resolution is ExactMerchantMatch) {
          state = state.copyWith(
            isExecuting: false,
            status: VoiceStatus.error,
            errorMessage: 'Merchant "${resolution.merchant.name}" already exists.',
          );
          return false;
        }

        await merchantRepository.createMerchant(
          CreateMerchantInput(
            name: command.merchantName,
            category: state.pendingCategory!,
            upiVpa: vpa,
            phone: null,
          ),
        );
      } else if (command is AddExpenseCommand) {
        final category = state.pendingExpenseCategory ?? command.category;
        if (category == null) {
          state = state.copyWith(
            isExecuting: false,
            status: VoiceStatus.error,
            errorMessage: 'Please select an expense category.',
          );
          return false;
        }

        if (command.amountPaise <= 0) {
          state = state.copyWith(
            isExecuting: false,
            status: VoiceStatus.error,
            errorMessage: 'Expense amount must be positive.',
          );
          return false;
        }

        if (command.note != null && command.note!.length > 200) {
          state = state.copyWith(
            isExecuting: false,
            status: VoiceStatus.error,
            errorMessage: 'Expense note cannot exceed 200 characters.',
          );
          return false;
        }

        await expenseRepository.createExpense(
          CreateExpenseInput(
            amountPaise: command.amountPaise,
            category: category,
            note: command.note,
            expenseDate: command.expenseDate,
          ),
        );
      }

      state = state.copyWith(
        isExecuting: false,
        status: VoiceStatus.completed,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isExecuting: false,
        status: VoiceStatus.error,
        errorMessage: 'Failed to execute command: ${e.toString()}',
      );
      return false;
    }
  }

  /// Sets the speech recognition locale (e.g. 'en_IN', 'hi_IN').
  void setLocale(String locale) {
    if (state.selectedLocale == locale) return;
    state = state.copyWith(selectedLocale: locale);
  }

  /// Resets the controller back to idle.
  void reset() {
    state = VoiceState(selectedLocale: state.selectedLocale);
  }
}

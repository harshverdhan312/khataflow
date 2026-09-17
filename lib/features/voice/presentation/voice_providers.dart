import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/voice_service.dart';
import '../../expense/presentation/expense_providers.dart';
import '../../ledger/presentation/ledger_providers.dart';
import '../../merchant/presentation/merchant_providers.dart';
import '../../settlement/presentation/settlement_providers.dart';
import '../data/deterministic_voice_command_parser.dart';
import '../domain/merchant_resolver.dart';
import '../domain/voice_command_parser.dart';
import 'voice_controller.dart';
import 'voice_state.dart';

/// Provider for the [VoiceService] singleton / instance.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  return SpeechToTextVoiceService();
});

/// Provider for the [VoiceCommandParser] abstraction.
final voiceCommandParserProvider = Provider<VoiceCommandParser>((ref) {
  return const DeterministicVoiceCommandParser();
});

/// Provider for the [MerchantResolver].
final merchantResolverProvider = Provider<MerchantResolver>((ref) {
  return const MerchantResolver();
});

/// Provider for the [VoiceController] state notifier.
final voiceControllerProvider =
    StateNotifierProvider<VoiceController, VoiceState>((ref) {
  final voiceService = ref.watch(voiceServiceProvider);
  final parser = ref.watch(voiceCommandParserProvider);
  final merchantRepo = ref.watch(merchantRepositoryProvider);
  final ledgerRepo = ref.watch(ledgerRepositoryProvider);
  final settlementRepo = ref.watch(settlementRepositoryProvider);
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final resolver = ref.watch(merchantResolverProvider);

  return VoiceController(
    voiceService: voiceService,
    parser: parser,
    merchantRepository: merchantRepo,
    ledgerRepository: ledgerRepo,
    settlementRepository: settlementRepo,
    expenseRepository: expenseRepo,
    merchantResolver: resolver,
  );
});

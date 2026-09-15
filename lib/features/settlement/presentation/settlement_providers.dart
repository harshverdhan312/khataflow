import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/database_provider.dart';
import '../../ledger/presentation/ledger_providers.dart';
import '../data/settlement_repository_impl.dart';
import '../domain/settlement.dart';
import '../domain/settlement_repository.dart';

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SettlementRepositoryImpl(db);
});

final unresolvedSettlementsForMerchantProvider =
    FutureProvider.family<List<Settlement>, String>((ref, merchantId) async {
  final repository = ref.watch(settlementRepositoryProvider);
  return repository.getUnresolvedSettlements(merchantId: merchantId);
});

final allUnresolvedSettlementsProvider =
    FutureProvider<List<Settlement>>((ref) async {
  final repository = ref.watch(settlementRepositoryProvider);
  return repository.getUnresolvedSettlements();
});

final merchantSettlementsStreamProvider =
    StreamProvider.family<List<Settlement>, String>((ref, merchantId) {
  final repository = ref.watch(settlementRepositoryProvider);
  return repository.watchSettlementsForMerchant(merchantId);
});

class SettlementFlowState {
  final bool isLoading;
  final String? errorMessage;
  final Settlement? activeSettlement;

  const SettlementFlowState({
    this.isLoading = false,
    this.errorMessage,
    this.activeSettlement,
  });

  SettlementFlowState copyWith({
    bool? isLoading,
    String? errorMessage,
    Settlement? activeSettlement,
  }) {
    return SettlementFlowState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeSettlement: activeSettlement ?? this.activeSettlement,
    );
  }
}

class SettlementController extends StateNotifier<SettlementFlowState> {
  final SettlementRepository settlementRepository;
  final Ref ref;

  SettlementController({
    required this.settlementRepository,
    required this.ref,
  }) : super(const SettlementFlowState());

  /// Records a manual settlement for all outstanding purchases of the given merchant.
  Future<SettlementFlowState> recordSettlement({
    required String merchantId,
    String? paymentReference,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final ledgerRepo = ref.read(ledgerRepositoryProvider);
      final unsettledPurchases = await ledgerRepo.getUnsettledPurchases(merchantId);
      if (unsettledPurchases.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No unsettled dues found for this store.',
        );
        return state;
      }

      final purchaseIds = unsettledPurchases.map((p) => p.id).toList();

      final settlement = await settlementRepository.recordSettlement(
        merchantId: merchantId,
        purchaseIds: purchaseIds,
        paymentReference: paymentReference,
      );

      // Invalidate relevant providers to refresh UI streams
      ref.invalidate(merchantOutstandingStreamProvider(merchantId));
      ref.invalidate(merchantPurchasesStreamProvider(merchantId));
      ref.invalidate(unresolvedSettlementsForMerchantProvider(merchantId));
      ref.invalidate(merchantSettlementsStreamProvider(merchantId));
      ref.invalidate(allUnresolvedSettlementsProvider);

      state = SettlementFlowState(
        isLoading: false,
        activeSettlement: settlement,
      );
      return state;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return state;
    }
  }

  /// Manually marks an unresolved settlement as SETTLED upon customer confirmation.
  Future<bool> recordSettlementAsSettled({
    required String settlementId,
    required String merchantId,
    String? transactionId,
    String? utr,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await settlementRepository.markSettlementSettled(
        settlementId: settlementId,
        transactionId: transactionId,
        utr: utr,
      );
      ref.invalidate(merchantOutstandingStreamProvider(merchantId));
      ref.invalidate(merchantPurchasesStreamProvider(merchantId));
      ref.invalidate(unresolvedSettlementsForMerchantProvider(merchantId));
      ref.invalidate(merchantSettlementsStreamProvider(merchantId));
      ref.invalidate(allUnresolvedSettlementsProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Records an unresolved settlement as FAILED.
  Future<void> recordSettlementAsFailed({
    required String settlementId,
    required String merchantId,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await settlementRepository.markSettlementFailed(
        settlementId: settlementId,
        reason: reason,
      );
      ref.invalidate(merchantOutstandingStreamProvider(merchantId));
      ref.invalidate(merchantPurchasesStreamProvider(merchantId));
      ref.invalidate(unresolvedSettlementsForMerchantProvider(merchantId));
      ref.invalidate(merchantSettlementsStreamProvider(merchantId));
      ref.invalidate(allUnresolvedSettlementsProvider);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Records an unresolved settlement as UNKNOWN.
  Future<void> recordSettlementAsUnknown({
    required String settlementId,
    required String merchantId,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await settlementRepository.markSettlementUnknown(
        settlementId: settlementId,
      );
      ref.invalidate(merchantOutstandingStreamProvider(merchantId));
      ref.invalidate(merchantPurchasesStreamProvider(merchantId));
      ref.invalidate(unresolvedSettlementsForMerchantProvider(merchantId));
      ref.invalidate(merchantSettlementsStreamProvider(merchantId));
      ref.invalidate(allUnresolvedSettlementsProvider);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final settlementControllerProvider =
    StateNotifierProvider<SettlementController, SettlementFlowState>((ref) {
  final settlementRepository = ref.watch(settlementRepositoryProvider);
  return SettlementController(
    settlementRepository: settlementRepository,
    ref: ref,
  );
});

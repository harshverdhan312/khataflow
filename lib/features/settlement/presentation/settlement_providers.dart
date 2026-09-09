import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/upi_service.dart';
import '../../../core/services/url_launcher_upi_service.dart';
import '../../../database/database_provider.dart';
import '../../ledger/presentation/ledger_providers.dart';
import '../data/settlement_repository_impl.dart';
import '../domain/settlement.dart';
import '../domain/settlement_repository.dart';

final upiServiceProvider = Provider<UpiService>((ref) {
  return const UrlLauncherUpiService();
});

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
  final UpiLaunchResult? launchResult;

  const SettlementFlowState({
    this.isLoading = false,
    this.errorMessage,
    this.activeSettlement,
    this.launchResult,
  });

  SettlementFlowState copyWith({
    bool? isLoading,
    String? errorMessage,
    Settlement? activeSettlement,
    UpiLaunchResult? launchResult,
  }) {
    return SettlementFlowState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeSettlement: activeSettlement ?? this.activeSettlement,
      launchResult: launchResult ?? this.launchResult,
    );
  }
}

class SettlementController extends StateNotifier<SettlementFlowState> {
  final SettlementRepository settlementRepository;
  final UpiService upiService;
  final Ref ref;

  SettlementController({
    required this.settlementRepository,
    required this.upiService,
    required this.ref,
  }) : super(const SettlementFlowState());

  /// Initiates a settlement for a merchant and launches the UPI application.
  Future<SettlementFlowState> initiateAndLaunchPayment({
    required String merchantId,
    required String merchantName,
    required String merchantVpa,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 1. Guard against duplicate / unresolved settlements
      final hasUnresolved = await settlementRepository.hasUnresolvedSettlementForMerchant(merchantId);
      if (hasUnresolved) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'An unresolved settlement already exists for this store. Please resolve it first.',
        );
        return state;
      }

      // 2. Validate VPA
      if (!upiService.isValidVpa(merchantVpa)) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'The store\'s UPI VPA ($merchantVpa) is invalid. Please update the store details.',
        );
        return state;
      }

      // 3. Read current unsettled purchases
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
      final totalPaise = unsettledPurchases.fold<int>(0, (sum, p) => sum + p.amountPaise);

      if (totalPaise <= 0) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Settlement amount must be greater than zero.',
        );
        return state;
      }

      // 4. Atomically create settlement and items in SQLite (INITIATED state)
      final settlement = await settlementRepository.initiateSettlement(
        merchantId: merchantId,
        purchaseIds: purchaseIds,
      );

      // 5. Transition to UPI_LAUNCHED state
      await settlementRepository.markUpiLaunched(settlement.id);

      // 6. Launch external UPI intent
      const note = 'Settlement_via_App';
      final launchResult = await upiService.launchPayment(
        vpa: merchantVpa,
        merchantName: merchantName,
        amountPaise: totalPaise,
        transactionNote: note,
      );

      if (launchResult.status != UpiLaunchStatus.launched) {
        // Record failure in settlement if launch could not succeed
        await settlementRepository.markSettlementFailed(
          settlementId: settlement.id,
          reason: launchResult.statusMessage ?? 'Failed to open UPI application',
        );
      }

      // Invalidate relevant providers to refresh UI streams
      ref.invalidate(merchantOutstandingStreamProvider(merchantId));
      ref.invalidate(merchantPurchasesStreamProvider(merchantId));
      ref.invalidate(unresolvedSettlementsForMerchantProvider(merchantId));

      state = SettlementFlowState(
        isLoading: false,
        activeSettlement: settlement,
        launchResult: launchResult,
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

  /// Manually marks a settlement as SETTLED upon customer confirmation.
  Future<void> recordSettlementAsSettled({
    required String settlementId,
    required String merchantId,
    String? transactionId,
    String? utr,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await settlementRepository.markSettlementSettled(
        settlementId: settlementId,
        transactionId: transactionId,
        utr: utr,
      );
      ref.invalidate(merchantOutstandingStreamProvider(merchantId));
      ref.invalidate(merchantPurchasesStreamProvider(merchantId));
      ref.invalidate(unresolvedSettlementsForMerchantProvider(merchantId));
      ref.invalidate(allUnresolvedSettlementsProvider);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Records a settlement as FAILED.
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
      ref.invalidate(allUnresolvedSettlementsProvider);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Records a settlement as UNKNOWN.
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
  final upiService = ref.watch(upiServiceProvider);
  return SettlementController(
    settlementRepository: settlementRepository,
    upiService: upiService,
    ref: ref,
  );
});

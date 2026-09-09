import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/database_provider.dart';
import '../data/ledger_repository_impl.dart';
import '../domain/ledger_repository.dart';
import '../domain/purchase.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LedgerRepositoryImpl(db);
});

final merchantPurchasesStreamProvider =
    StreamProvider.family<List<Purchase>, String>((ref, merchantId) {
  final repo = ref.watch(ledgerRepositoryProvider);
  return repo.watchPurchases(merchantId);
});

final merchantOutstandingStreamProvider =
    StreamProvider.family<int, String>((ref, merchantId) {
  final repo = ref.watch(ledgerRepositoryProvider);
  return repo.watchOutstandingAmount(merchantId);
});

final totalOutstandingStreamProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(ledgerRepositoryProvider);
  return repo.watchTotalOutstanding();
});

class AddPurchaseState {
  final bool isLoading;
  final String? errorMessage;
  final Purchase? createdPurchase;

  const AddPurchaseState({
    this.isLoading = false,
    this.errorMessage,
    this.createdPurchase,
  });

  AddPurchaseState copyWith({
    bool? isLoading,
    String? errorMessage,
    Purchase? createdPurchase,
  }) {
    return AddPurchaseState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      createdPurchase: createdPurchase ?? this.createdPurchase,
    );
  }
}

class AddPurchaseController extends StateNotifier<AddPurchaseState> {
  final LedgerRepository _repository;

  AddPurchaseController(this._repository) : super(const AddPurchaseState());

  Future<bool> submit(CreatePurchaseInput input) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final purchase = await _repository.addPurchase(input);
      state = state.copyWith(isLoading: false, createdPurchase: purchase);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final addPurchaseControllerProvider =
    StateNotifierProvider<AddPurchaseController, AddPurchaseState>((ref) {
  final repo = ref.watch(ledgerRepositoryProvider);
  return AddPurchaseController(repo);
});

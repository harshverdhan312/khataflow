import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/database_provider.dart';
import '../data/merchant_repository_impl.dart';
import '../domain/merchant.dart';
import '../domain/merchant_repository.dart';

final merchantRepositoryProvider = Provider<MerchantRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return MerchantRepositoryImpl(db);
});

final activeMerchantsStreamProvider = StreamProvider<List<Merchant>>((ref) {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.watchActiveMerchants();
});

final merchantDetailProvider = FutureProvider.family<Merchant?, String>((ref, id) {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getMerchantById(id);
});

class AddMerchantState {
  final bool isLoading;
  final String? errorMessage;
  final Merchant? createdMerchant;

  const AddMerchantState({
    this.isLoading = false,
    this.errorMessage,
    this.createdMerchant,
  });

  AddMerchantState copyWith({
    bool? isLoading,
    String? errorMessage,
    Merchant? createdMerchant,
  }) {
    return AddMerchantState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      createdMerchant: createdMerchant ?? this.createdMerchant,
    );
  }
}

class AddMerchantController extends StateNotifier<AddMerchantState> {
  final MerchantRepository _repository;

  AddMerchantController(this._repository) : super(const AddMerchantState());

  Future<bool> submit(CreateMerchantInput input) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final merchant = await _repository.createMerchant(input);
      state = state.copyWith(isLoading: false, createdMerchant: merchant);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deactivateMerchant(String merchantId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deactivateMerchant(merchantId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final addMerchantControllerProvider =
    StateNotifierProvider<AddMerchantController, AddMerchantState>((ref) {
  final repo = ref.watch(merchantRepositoryProvider);
  return AddMerchantController(repo);
});

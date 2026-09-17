import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/database_provider.dart';
import '../data/expense_repository_impl.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ExpenseRepositoryImpl(db);
});

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchExpenses();
});

final expenseDetailProvider = FutureProvider.family<Expense?, String>((ref, id) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpenseById(id);
});

class AddExpenseState {
  final bool isLoading;
  final String? errorMessage;
  final Expense? createdExpense;

  const AddExpenseState({
    this.isLoading = false,
    this.errorMessage,
    this.createdExpense,
  });

  AddExpenseState copyWith({
    bool? isLoading,
    String? errorMessage,
    Expense? createdExpense,
  }) {
    return AddExpenseState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      createdExpense: createdExpense ?? this.createdExpense,
    );
  }
}

class AddExpenseController extends StateNotifier<AddExpenseState> {
  final ExpenseRepository _repository;

  AddExpenseController(this._repository) : super(const AddExpenseState());

  Future<bool> submit(CreateExpenseInput input) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final expense = await _repository.createExpense(input);
      state = state.copyWith(isLoading: false, createdExpense: expense);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> update(UpdateExpenseInput input) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updateExpense(input);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> delete(String id) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deleteExpense(id);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final addExpenseControllerProvider =
    StateNotifierProvider<AddExpenseController, AddExpenseState>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return AddExpenseController(repo);
});


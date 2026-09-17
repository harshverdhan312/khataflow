import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/expense/presentation/add_expense_screen.dart';
import '../features/expense/presentation/edit_expense_screen.dart';
import '../features/expense/presentation/screens/spending_insights_screen.dart';
import '../features/ledger/presentation/ledger_screen.dart';
import '../features/merchant/presentation/add_merchant_screen.dart';
import '../features/merchant/presentation/edit_merchant_screen.dart';
import '../features/navigation/presentation/main_nav_screen.dart';
import '../features/receipt/presentation/settlement_receipt_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const MainNavScreen(),
      ),
      GoRoute(
        path: '/merchant/add',
        name: 'addMerchant',
        builder: (context, state) => const AddMerchantScreen(),
      ),
      GoRoute(
        path: '/merchant/edit/:merchantId',
        name: 'editMerchant',
        builder: (context, state) {
          final merchantId = state.pathParameters['merchantId'] ?? '';
          return EditMerchantScreen(merchantId: merchantId);
        },
      ),
      GoRoute(
        path: '/ledger/:merchantId',
        name: 'ledger',
        builder: (context, state) {
          final merchantId = state.pathParameters['merchantId'] ?? '';
          return LedgerScreen(merchantId: merchantId);
        },
      ),
      GoRoute(
        path: '/receipt/:settlementId',
        name: 'settlementReceipt',
        builder: (context, state) {
          final settlementId = state.pathParameters['settlementId'] ?? '';
          return SettlementReceiptScreen(settlementId: settlementId);
        },
      ),
      GoRoute(
        path: '/expense/add',
        name: 'addExpense',
        builder: (context, state) => const AddExpenseScreen(),
      ),
      GoRoute(
        path: '/expense/edit/:expenseId',
        name: 'editExpense',
        builder: (context, state) {
          final expenseId = state.pathParameters['expenseId'] ?? '';
          return EditExpenseScreen(expenseId: expenseId);
        },
      ),
      GoRoute(
        path: '/expense/insights',
        name: 'spendingInsights',
        builder: (context, state) => const SpendingInsightsScreen(),
      ),
    ],
  );
});


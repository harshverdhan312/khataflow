import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/ledger/presentation/ledger_screen.dart';
import '../features/merchant/presentation/add_merchant_screen.dart';
import '../features/merchant/presentation/edit_merchant_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
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
    ],
  );
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../expense/presentation/expense_history_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';

final mainNavIndexProvider = StateProvider<int>((ref) => 0);

class MainNavScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends ConsumerState<MainNavScreen> {
  final List<Widget> _screens = const [
    DashboardScreen(),
    ExpenseHistoryScreen(),
    TransactionsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != 0) {
      Future.microtask(() {
        if (mounted) {
          ref.read(mainNavIndexProvider.notifier).state = widget.initialIndex;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainNavIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardDark,
          border: Border(
            top: BorderSide(color: AppColors.borderDark, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            ref.read(mainNavIndexProvider.notifier).state = index;
          },
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondaryDark,
          backgroundColor: AppColors.cardDark,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.payments_outlined),
              activeIcon: Icon(Icons.payments_rounded),
              label: 'Transactions',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../navigation/presentation/main_nav_screen.dart';
import '../../voice/presentation/voice_controller.dart';
import '../../voice/presentation/voice_entry_sheet.dart';
import '../../voice/presentation/voice_providers.dart';
import '../../voice/presentation/voice_state.dart';
import '../../voice/presentation/widgets/voice_pulse_mic_button.dart';

/// The central voice-first Home screen of KhataFlow.
///
/// Features a prominent, accessible microphone button with live listening animations,
/// language toggle, quick voice command prompts, and financial quick glances.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceControllerProvider);
    final voiceController = ref.read(voiceControllerProvider.notifier);
    final dashboardSummaryAsync = ref.watch(dashboardSummaryStreamProvider);
    final expenseSummaryAsync = ref.watch(expenseDashboardSummaryProvider);

    final isListening = voiceState.status == VoiceStatus.listening;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/branding/khataflow_icon.png',
              height: 26,
              width: 26,
              errorBuilder: (_, _, _) => const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.textPrimaryDark,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          _buildLanguageToggle(voiceState, voiceController),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),

                    // Top Voice Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isListening ? Icons.graphic_eq_rounded : Icons.auto_awesome_rounded,
                            size: 16,
                            color: isListening ? const Color(0xFFEF4444) : AppColors.primaryLight,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isListening ? 'Listening to speech...' : 'Voice-First Ledger',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isListening ? const Color(0xFFEF4444) : AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Center Primary Microphone Action with Ripple Animation
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VoicePulseMicButton(
                            isListening: isListening,
                            size: 112.0,
                            onTap: () => VoiceEntrySheet.show(context),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isListening ? 'Listening...' : 'Tap to speak / add something',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Add a purchase, payment, or expense with voice',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryDark,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Example voice command prompts
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0, bottom: 10.0),
                          child: Text(
                            'TRY SAYING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPromptChip(
                              context,
                              icon: Icons.shopping_bag_outlined,
                              text: 'Sharma se doodh 60 liya',
                            ),
                            _buildPromptChip(
                              context,
                              icon: Icons.restaurant_outlined,
                              text: 'I spent 250 on food',
                            ),
                            _buildPromptChip(
                              context,
                              icon: Icons.payments_outlined,
                              text: 'Gupta ko 500 de diye',
                            ),
                            _buildPromptChip(
                              context,
                              icon: Icons.storefront_outlined,
                              text: 'Sharma ki dukaan add karo',
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Bottom Quick Financial Glances
                    Row(
                      children: [
                        // Outstanding Snapshot
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              ref.read(mainNavIndexProvider.notifier).state = 0; // Jump to Ledger
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.borderDark),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total Outstanding',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondaryDark,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 11,
                                        color: AppColors.textSecondaryDark.withValues(alpha: 0.7),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  dashboardSummaryAsync.when(
                                    data: (summary) => Text(
                                      CurrencyFormatter.formatPaise(summary.totalOutstandingPaise),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: summary.totalOutstandingPaise > 0
                                            ? AppColors.outstandingRed
                                            : AppColors.settledGreen,
                                      ),
                                    ),
                                    loading: () => const Text('...', style: TextStyle(color: Colors.white70)),
                                    error: (_, _) => const Text('—', style: TextStyle(color: Colors.white70)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Monthly Spending Snapshot
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              ref.read(mainNavIndexProvider.notifier).state = 2; // Jump to Expenses
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cardDark,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.borderDark),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'This Month',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondaryDark,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 11,
                                        color: AppColors.textSecondaryDark.withValues(alpha: 0.7),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  expenseSummaryAsync.when(
                                    data: (expSummary) => Text(
                                      CurrencyFormatter.formatPaise(expSummary.totalAmountPaise),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimaryDark,
                                      ),
                                    ),
                                    loading: () => const Text('...', style: TextStyle(color: Colors.white70)),
                                    error: (_, _) => const Text('—', style: TextStyle(color: Colors.white70)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLanguageToggle(VoiceState state, VoiceController controller) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLanguageOption(
            label: 'EN',
            isSelected: state.selectedLocale == 'en_IN',
            onTap: () => controller.setLocale('en_IN'),
          ),
          _buildLanguageOption(
            label: 'हिन्दी',
            isSelected: state.selectedLocale == 'hi_IN',
            onTap: () => controller.setLocale('hi_IN'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }

  Widget _buildPromptChip(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return InkWell(
      onTap: () => VoiceEntrySheet.show(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryLight),
            const SizedBox(width: 6),
            Text(
              '"$text"',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import 'voice_confirmation_view.dart';
import 'voice_controller.dart';
import 'voice_providers.dart';
import 'voice_state.dart';

/// Modal bottom sheet for voice input, transcript capture, disambiguation,
/// and explicit ledger command confirmation.
class VoiceEntrySheet extends ConsumerStatefulWidget {
  const VoiceEntrySheet({super.key});

  /// Displays the [VoiceEntrySheet] modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceEntrySheet(),
    );
  }

  @override
  ConsumerState<VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends ConsumerState<VoiceEntrySheet> {
  @override
  void initState() {
    super.initState();
    // Automatically start listening upon opening sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceControllerProvider.notifier).startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceControllerProvider);
    final voiceController = ref.read(voiceControllerProvider.notifier);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Row: Title & Language Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Voice Ledger',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  _buildLanguageToggle(voiceState, voiceController),
                ],
              ),

              const SizedBox(height: 20),

              // Dynamic Body based on VoiceStatus
              if (voiceState.status == VoiceStatus.idle)
                _buildIdleView(voiceController)
              else if (voiceState.status == VoiceStatus.listening)
                _buildListeningView(voiceState, voiceController)
              else if (voiceState.status == VoiceStatus.processing)
                _buildProcessingView(voiceState)
              else if (voiceState.status == VoiceStatus.aiFallback)
                _buildAiFallbackView(voiceState, voiceController)
              else if (voiceState.status == VoiceStatus.ambiguousMerchant ||
                  voiceState.status == VoiceStatus.commandReady)
                VoiceConfirmationView(
                  voiceState: voiceState,
                  voiceController: voiceController,
                  onDismiss: () => Navigator.of(context).pop(),
                )
              else if (voiceState.status == VoiceStatus.completed)
                _buildCompletedView(voiceState, voiceController)
              else if (voiceState.status == VoiceStatus.error)
                _buildErrorView(voiceState, voiceController),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageToggle(VoiceState state, VoiceController controller) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLanguageOption(
            label: 'English',
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildIdleView(VoiceController controller) {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          'Tap the microphone to speak.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: IconButton.filled(
            onPressed: () => controller.startListening(),
            icon: const Icon(Icons.mic_rounded, size: 36),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(20),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildListeningView(VoiceState state, VoiceController controller) {
    final transcriptText = state.transcript?.text ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Listening...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            transcriptText.isNotEmpty
                ? '"$transcriptText"'
                : 'Speak now (e.g. "Sharma se doodh 60 aur bread 40 ka liya")...',
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              fontStyle: transcriptText.isEmpty ? FontStyle.italic : FontStyle.normal,
              color: transcriptText.isNotEmpty
                  ? AppColors.textPrimaryLight
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  controller.cancelListening();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => controller.stopListening(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessingView(VoiceState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Center(
          child: SizedBox(
            height: 40,
            width: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'Analyzing speech...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (state.transcript?.text != null &&
            state.transcript!.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              '"${state.transcript!.text}"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAiFallbackView(VoiceState state, VoiceController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Center(
          child: SizedBox(
            height: 40,
            width: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'Trying another way to understand that...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (state.transcript?.text != null &&
            state.transcript!.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              '"${state.transcript!.text}"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                 fontSize: 13,
                 fontStyle: FontStyle.italic,
                 color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () {
              controller.cancelCommand();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedView(VoiceState state, VoiceController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.settledGreen,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              'Recorded in Ledger',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.settledGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.settledGreen.withValues(alpha: 0.4)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.task_alt_rounded,
                color: AppColors.settledGreen,
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Transaction successfully recorded in your local ledger.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            controller.cancelCommand();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.settledGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(VoiceState state, VoiceController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.outstandingRed,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Could not process voice entry',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.outstandingRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.outstandingRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.outstandingRed.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            state.errorMessage ?? 'An error occurred while processing the voice entry.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.outstandingRed,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  controller.cancelListening();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Enter Manually'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => controller.startListening(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// A prominent circular microphone button that displays smooth concentric ripple
/// animations when active/listening.
class VoicePulseMicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  final double size;
  final String semanticLabel;

  const VoicePulseMicButton({
    super.key,
    required this.isListening,
    required this.onTap,
    this.size = 116.0,
    this.semanticLabel = 'Tap to speak voice command',
  });

  @override
  State<VoicePulseMicButton> createState() => _VoicePulseMicButtonState();
}

class _VoicePulseMicButtonState extends State<VoicePulseMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    if (widget.isListening) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VoicePulseMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.size * 1.8,
          height: widget.size * 1.8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple Wave 2 (Outer)
              if (widget.isListening)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final progress = (_controller.value + 0.5) % 1.0;
                    final scale = 1.0 + (progress * 0.7);
                    final opacity = (1.0 - progress).clamp(0.0, 0.4);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: opacity),
                        ),
                      ),
                    );
                  },
                ),

              // Ripple Wave 1 (Inner)
              if (widget.isListening)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final progress = _controller.value;
                    final scale = 1.0 + (progress * 0.5);
                    final opacity = (1.0 - progress).clamp(0.0, 0.6);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: opacity),
                        ),
                      ),
                    );
                  },
                ),

              // Main Circular Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: widget.isListening
                        ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                        : [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isListening
                              ? const Color(0xFFEF4444)
                              : AppColors.primary)
                          .withValues(alpha: widget.isListening ? 0.5 : 0.35),
                      blurRadius: widget.isListening ? 28 : 20,
                      spreadRadius: widget.isListening ? 4 : 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.isListening ? Icons.mic_rounded : Icons.mic_rounded,
                    size: widget.size * 0.45,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

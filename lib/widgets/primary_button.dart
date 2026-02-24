import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import 'breathing_glow.dart';

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.breathing = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool breathing;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final childButton = widget.icon == null
        ? FilledButton(
            onPressed: widget.onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.midnight,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            child: Text(widget.label),
          )
        : FilledButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(widget.icon, size: 18),
            label: Text(widget.label),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.midnight,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
          );

    final button = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.96 : 1,
        curve: Curves.easeOutCubic,
        child: childButton,
      ),
    );

    if (!widget.breathing) {
      return button;
    }
    return BreathingGlow(child: button);
  }
}


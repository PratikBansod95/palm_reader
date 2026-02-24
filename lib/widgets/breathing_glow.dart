import 'package:flutter/material.dart';

import '../core/theme/colors.dart';

class BreathingGlow extends StatefulWidget {
  const BreathingGlow({required this.child, super.key, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = 8 + (_controller.value * 10);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.22),
                blurRadius: glow,
                spreadRadius: 1.2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}


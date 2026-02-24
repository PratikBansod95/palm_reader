import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import 'shimmer_reveal.dart';

class GlowingHeader extends StatefulWidget {
  const GlowingHeader({required this.title, super.key});

  final String title;

  @override
  State<GlowingHeader> createState() => _GlowingHeaderState();
}

class _GlowingHeaderState extends State<GlowingHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1,
            colors: [
              AppColors.gold.withOpacity(0.26),
              Colors.transparent,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: ShimmerReveal(
            child: Text(
              widget.title,
              style: textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}


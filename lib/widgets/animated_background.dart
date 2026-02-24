import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import 'particle_overlay.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({
    required this.child,
    super.key,
    this.showMandala = false,
  });

  final Widget child;
  final bool showMandala;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + (t * 0.8), -1),
              end: Alignment(1, 1 - (t * 0.7)),
              colors: const [
                AppColors.midnight,
                AppColors.deepIndigo,
                AppColors.indigoBloom,
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ParticleOverlay(),
              if (widget.showMandala)
                IgnorePointer(
                  child: CustomPaint(painter: _MandalaPainter(opacity: 0.07)),
                ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _MandalaPainter extends CustomPainter {
  _MandalaPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.28);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.softGold.withOpacity(opacity)
      ..strokeWidth = 1;

    for (var i = 1; i <= 6; i++) {
      canvas.drawCircle(center, 28.0 * i, paint);
    }

    for (var i = 0; i < 12; i++) {
      final angle = (pi * 2 / 12) * i;
      final p1 = center + Offset(cos(angle), sin(angle)) * 20;
      final p2 = center + Offset(cos(angle), sin(angle)) * 170;
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MandalaPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}


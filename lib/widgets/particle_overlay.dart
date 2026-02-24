import 'package:flutter/material.dart';

import '../core/theme/colors.dart';

class ParticleOverlay extends StatefulWidget {
  const ParticleOverlay({super.key});

  @override
  State<ParticleOverlay> createState() => _ParticleOverlayState();
}

class _ParticleOverlayState extends State<ParticleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        painter: _ParticlePainter(progress: _controller.value),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 36; i++) {
      final seed = i * 31.0;
      final x = ((seed * 19) % size.width + progress * 14 * i) % size.width;
      final y = ((seed * 11) % size.height + progress * 7 * i) % size.height;
      final radius = 0.9 + (i % 4) * 0.6;
      paint.color = AppColors.softGold.withOpacity(0.04 + ((i % 6) * 0.01));
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}


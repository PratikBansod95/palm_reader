import 'package:flutter/material.dart';

class ShimmerReveal extends StatefulWidget {
  const ShimmerReveal({required this.child, super.key});

  final Widget child;

  @override
  State<ShimmerReveal> createState() => _ShimmerRevealState();
}

class _ShimmerRevealState extends State<ShimmerReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final x = _controller.value * 1.6 - 0.4;
            return LinearGradient(
              begin: Alignment(-1 + x, 0),
              end: Alignment(1 + x, 0),
              colors: [
                Colors.white.withOpacity(0.85),
                Colors.white,
                Colors.white.withOpacity(0.85),
              ],
              stops: const [0, 0.5, 1],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }
}


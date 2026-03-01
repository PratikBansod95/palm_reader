import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../models/reading_context_model.dart';
import '../../widgets/animated_background.dart';

class LanguageHandScreen extends StatefulWidget {
  const LanguageHandScreen({super.key});

  @override
  State<LanguageHandScreen> createState() => _LanguageHandScreenState();
}

class _LanguageHandScreenState extends State<LanguageHandScreen> {
  String _language = 'English';
  String _hand = 'Right';
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AnimatedBackground(
        showMandala: false,
        child: Stack(
          children: [
            const Positioned.fill(child: _SkyOverlay()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),
                    Center(
                      child: Text(
                        'Your Destiny',
                        style: textTheme.displaySmall?.copyWith(fontSize: 62),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Let\'s reveal what your hands are hiding.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                          fontSize: 19,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 26),
                    _StepLabel(text: 'Step 1 of 3'),
                    const SizedBox(height: 34),
                    _SectionHeading(
                      title: 'Language',
                      icon: Icons.public,
                    ),
                    const SizedBox(height: 12),
                    _SelectionRow(
                      options: const ['English', 'Hindi'],
                      selected: _language,
                      onSelected: (v) => setState(() => _language = v),
                    ),
                    const SizedBox(height: 30),
                    _SectionHeading(
                      title: 'Dominant Hand',
                      icon: Icons.pan_tool_alt_rounded,
                    ),
                    const SizedBox(height: 12),
                    _SelectionRow(
                      options: const ['Right', 'Left'],
                      selected: _hand,
                      onSelected: (v) => setState(() => _hand = v),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'The hand you write with',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTapDown: (_) => setState(() => _pressed = true),
                      onTapCancel: () => setState(() => _pressed = false),
                      onTapUp: (_) => setState(() => _pressed = false),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 120),
                        scale: _pressed ? 0.97 : 1,
                        curve: Curves.easeOutCubic,
                        child: _ContinueButton(
                          onTap: () => context.go(
                            '/capture',
                            extra: OnboardingSelection(
                              language: _language,
                              dominantHand: _hand,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueButton extends StatefulWidget {
  const _ContinueButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
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
        final glow = 24 + (_controller.value * 24);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.55),
                blurRadius: glow + 8,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.35),
                blurRadius: glow,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(36),
        onTap: widget.onTap,
        child: Ink(
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: AppColors.softGold.withValues(alpha: 0.95), width: 1.3),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFF4D985),
                Color(0xFFE1BE57),
                Color(0xFFF8DD8A),
              ],
            ),
          ),
          child: Center(
            child: Text(
              'Continue ->',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.midnight,
                    fontSize: 26,
                    letterSpacing: 0.3,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.softGold.withValues(alpha: 0.92), size: 26),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 48),
        ),
      ],
    );
  }
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options
          .asMap()
          .entries
          .map(
            (entry) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: entry.key == 0 ? 12 : 0),
                child: _GoldPillOption(
                  label: entry.value,
                  selected: selected == entry.value,
                  onTap: () => onSelected(entry.value),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _GoldPillOption extends StatelessWidget {
  const _GoldPillOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      child: Ink(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: selected
              ? AppColors.softGold.withValues(alpha: 0.1)
              : AppColors.midnight.withValues(alpha: 0.16),
          border: Border.all(
            color: selected
                ? AppColors.softGold.withValues(alpha: 0.95)
                : AppColors.softGold.withValues(alpha: 0.45),
            width: 1.3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.22),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check : Icons.circle_outlined,
              size: selected ? 22 : 18,
              color: AppColors.softGold.withValues(alpha: selected ? 1 : 0.6),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      color: AppColors.textPrimary.withValues(alpha: 0.95),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.softGold.withValues(alpha: 0.35),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.softGold.withValues(alpha: 0.92),
                  fontSize: 18,
                  letterSpacing: 0.4,
                ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.softGold.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _SkyOverlay extends StatefulWidget {
  const _SkyOverlay();

  @override
  State<_SkyOverlay> createState() => _SkyOverlayState();
}

class _SkyOverlayState extends State<_SkyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
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
      builder: (context, child) {
        return CustomPaint(
          painter: _SkyPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 280; i++) {
      final baseX = ((i * 53.0) % size.width);
      final baseY = ((i * 97.0) % size.height);
      final twinkle = (sin((progress * 2 * pi) + (i * 0.37)) + 1) * 0.5;
      final alpha = 0.05 + (twinkle * 0.33);
      final radius = (i % 9 == 0) ? 1.7 : (0.4 + ((i % 4) * 0.35));

      starPaint.color = AppColors.softGold.withValues(alpha: alpha);
      canvas.drawCircle(Offset(baseX, baseY), radius, starPaint);

      if (i % 26 == 0) {
        _drawSparkle(canvas, Offset(baseX, baseY), 7 + (twinkle * 6));
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1
      ..color = AppColors.softGold.withValues(alpha: 0.18 + (0.08 * sin(progress * 2 * pi)));

    final nodes = <Offset>[
      Offset(size.width * 0.14, size.height * 0.2),
      Offset(size.width * 0.24, size.height * 0.17),
      Offset(size.width * 0.32, size.height * 0.23),
      Offset(size.width * 0.72, size.height * 0.12),
      Offset(size.width * 0.82, size.height * 0.16),
      Offset(size.width * 0.9, size.height * 0.22),
      Offset(size.width * 0.16, size.height * 0.78),
      Offset(size.width * 0.24, size.height * 0.84),
      Offset(size.width * 0.33, size.height * 0.8),
      Offset(size.width * 0.71, size.height * 0.74),
      Offset(size.width * 0.85, size.height * 0.79),
      Offset(size.width * 0.9, size.height * 0.86),
    ];

    final links = <List<int>>[
      [0, 1],
      [1, 2],
      [3, 4],
      [4, 5],
      [6, 7],
      [7, 8],
      [9, 10],
      [10, 11],
    ];

    for (final link in links) {
      canvas.drawLine(nodes[link[0]], nodes[link[1]], linePaint);
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.softGold.withValues(alpha: 0.12);

    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * 0.5, size.height * 0.45), radius: size.width * 0.52),
      pi * 0.08,
      pi * 1.74,
      false,
      arcPaint,
    );
  }

  void _drawSparkle(Canvas canvas, Offset c, double length) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1
      ..color = AppColors.softGold.withValues(alpha: 0.5);

    canvas.drawLine(Offset(c.dx - length, c.dy), Offset(c.dx + length, c.dy), p);
    canvas.drawLine(Offset(c.dx, c.dy - length), Offset(c.dx, c.dy + length), p);
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

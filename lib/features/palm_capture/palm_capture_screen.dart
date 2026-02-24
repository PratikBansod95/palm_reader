import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../services/image_validator.dart';
import '../../widgets/animated_background.dart';

class PalmCaptureScreen extends ConsumerStatefulWidget {
  const PalmCaptureScreen({super.key});

  @override
  ConsumerState<PalmCaptureScreen> createState() => _PalmCaptureScreenState();
}

class _PalmCaptureScreenState extends ConsumerState<PalmCaptureScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    final valid = await ref.read(imageValidatorProvider).validatePalmImage();
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);

    if (valid) {
      context.go('/scanning');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Capture Not Clear'),
        content: const Text(
          'Your palm image needs clearer lighting and full visibility.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Place your palm', style: textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Align your dominant hand inside the guide frame.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.cardBase,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.cardStroke),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withOpacity(0.08),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Container(
                                width: 220,
                                height: 320,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: AppColors.softGold.withOpacity(0.8),
                                    width: 1.3,
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Icon(
                                Icons.pan_tool_alt_outlined,
                                color: AppColors.softGold.withOpacity(0.5),
                                size: 120,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: _loading ? null : _capture,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulse = 6 + (_pulseController.value * 14);
                            return Container(
                              width: 94,
                              height: 94,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.gold.withOpacity(0.24),
                                    blurRadius: pulse,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          },
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.gold,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: AppColors.midnight,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              if (_loading)
                const ColoredBox(
                  color: Color(0x99000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


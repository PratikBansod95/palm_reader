import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/animation_timings.dart';
import '../../core/theme/colors.dart';
import '../../models/reading_context_model.dart';
import '../../services/openai_palm_service.dart';
import '../../widgets/animated_background.dart';

class ScanningScreen extends ConsumerStatefulWidget {
  const ScanningScreen({
    required this.request,
    super.key,
  });

  final ScanRequest request;

  @override
  ConsumerState<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends ConsumerState<ScanningScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _steps = const [
    'Scanning surface patterns...',
    'Mapping emotional currents...',
    'Interpreting karmic imprints...',
    'Analyzing life path indicators...',
    'Finalizing destiny blueprint...',
  ];

  late final AnimationController _beamController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  Timer? _timer;
  int _index = 0;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(AnimationTimings.scanStep, (timer) async {
      if (!mounted) {
        return;
      }

      if (_index < _steps.length - 1) {
        setState(() => _index++);
      }

      if (timer.tick >= AnimationTimings.scanTotal.inSeconds && !_navigating) {
        _navigating = true;
        timer.cancel();
        await _runAnalysis();
      }
    });
  }

  Future<void> _runAnalysis() async {
    try {
      HapticFeedback.heavyImpact();
      final result = await ref.read(openAiPalmServiceProvider).fetchPalmReading(
            imageBytes: widget.request.imageBytes,
            language: widget.request.language,
            dominantHand: widget.request.dominantHand,
          );
      if (!mounted) {
        return;
      }
      context.go('/results', extra: result);
    } catch (error) {
      _navigating = false;
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Analysis Failed'),
          content: Text('Could not analyze your palm right now.\n$error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go(
                  '/capture',
                  extra: OnboardingSelection(
                    language: widget.request.language,
                    dominantHand: widget.request.dominantHand,
                  ),
                );
              },
              child: const Text('Recapture'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _beamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text('Destiny Scan', style: textTheme.headlineMedium),
                const SizedBox(height: 24),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.cardBase,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.cardStroke),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.28,
                              child: Image.memory(
                                widget.request.imageBytes,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.midnight.withValues(alpha: 0.26),
                                    AppColors.deepIndigo.withValues(alpha: 0.20),
                                    AppColors.midnight.withValues(alpha: 0.32),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Icon(
                              Icons.pan_tool_alt_rounded,
                              color: AppColors.softGold.withValues(alpha: 0.35),
                              size: 170,
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _beamController,
                            builder: (context, child) {
                              final y = (_beamController.value * 0.88) + 0.06;
                              return Align(
                                alignment: Alignment(0, (y * 2) - 1),
                                child: Container(
                                  height: 7,
                                  margin: const EdgeInsets.symmetric(horizontal: 22),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        AppColors.softGold.withValues(alpha: 0.95),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gold.withValues(alpha: 0.45),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _steps[_index],
                    key: ValueKey(_index),
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

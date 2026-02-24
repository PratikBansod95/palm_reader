import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/animation_timings.dart';
import '../../core/theme/colors.dart';
import '../../services/mock_api_service.dart';
import '../../widgets/animated_background.dart';

class ScanningScreen extends ConsumerStatefulWidget {
  const ScanningScreen({super.key});

  @override
  ConsumerState<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends ConsumerState<ScanningScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _steps = const [
    'Scanning surface patterns…',
    'Mapping emotional currents…',
    'Interpreting karmic imprints…',
    'Analyzing life path indicators…',
    'Finalizing destiny blueprint…',
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
        HapticFeedback.heavyImpact();
        final result = await ref.read(mockApiServiceProvider).fetchPalmReading();
        if (!mounted) {
          return;
        }
        context.go('/results', extra: result);
      }
    });
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
                          Center(
                            child: Icon(
                              Icons.pan_tool_alt_rounded,
                              color: AppColors.softGold.withOpacity(0.45),
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
                                        AppColors.softGold.withOpacity(0.95),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gold.withOpacity(0.45),
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


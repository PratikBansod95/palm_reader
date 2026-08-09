import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../models/reading_context_model.dart';
import '../../services/palm_analysis_service.dart';
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

  Timer? _stepTimer;
  int _index = 0;
  bool _navigating = false;
  bool _analyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1100), (timer) {
      if (!mounted || _index >= _steps.length - 1) {
        return;
      }
      setState(() => _index++);
    });
    unawaited(_runAnalysis());
  }

  Future<void> _runAnalysis() async {
    if (_analyzing || _navigating) {
      return;
    }
    setState(() {
      _analyzing = true;
      _error = null;
    });

    final startedAt = DateTime.now();
    try {
      HapticFeedback.heavyImpact();
      final result =
          await ref.read(palmAnalysisServiceProvider).fetchPalmReading(
                imageBytes: widget.request.imageBytes,
                language: widget.request.language,
                dominantHand: widget.request.dominantHand,
              );

      final elapsed = DateTime.now().difference(startedAt);
      const minDwell = Duration(milliseconds: 1500);
      if (elapsed < minDwell) {
        await Future<void>.delayed(minDwell - elapsed);
      }

      if (!mounted) {
        return;
      }
      _navigating = true;
      _stepTimer?.cancel();
      context.go('/results', extra: result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _analyzing = false;
        _error = _toUiError(error);
      });
      await _showErrorDialog();
    }
  }

  Future<void> _showErrorDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Analysis Failed'),
        content: Text(
          'Could not analyze your palm right now.\n${_error ?? 'Unknown error'}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_runAnalysis());
            },
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

  String _toUiError(Object error) {
    final text = error.toString();
    const prefix = 'Exception: ';
    if (text.startsWith(prefix)) {
      return text.substring(prefix.length);
    }
    return text;
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
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
                const SizedBox(height: 8),
                Text(
                  ref.read(palmAnalysisServiceProvider).isDemoMode
                      ? 'Preparing your personalized reading'
                      : 'Connecting to the analysis guide',
                  style: textTheme.bodyMedium,
                ),
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
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        AppColors.softGold
                                            .withValues(alpha: 0.95),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.45),
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

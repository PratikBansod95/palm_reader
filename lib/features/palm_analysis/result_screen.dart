import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/animation_timings.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/colors.dart';
import '../../models/palm_result_model.dart';
import '../../widgets/ai_status_banner.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/primary_button.dart';
import 'widgets/glowing_header.dart';
import 'widgets/section_card.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({required this.result, super.key});

  final PalmResultModel result;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int _visibleSections = 0;
  Timer? _timer;
  bool get _hasNarrative => widget.result.fullReading.trim().isNotEmpty;

  List<MapEntry<String, String>> get _sections => [
        MapEntry('Personality', widget.result.personality),
        MapEntry('Life Path', widget.result.lifePath),
        MapEntry('Love', widget.result.love),
        MapEntry('Wealth', widget.result.wealth),
        MapEntry('Challenges', widget.result.challenges),
        MapEntry('Guidance', widget.result.guidance),
      ];

  List<String> get _paragraphs {
    return widget.result.fullReading
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    HapticFeedback.selectionClick();
    if (_hasNarrative) {
      _visibleSections = _sections.length;
      return;
    }
    _timer = Timer.periodic(AnimationTimings.sectionStagger, (timer) {
      if (!mounted) {
        return;
      }
      if (_visibleSections < _sections.length) {
        setState(() => _visibleSections++);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const GlowingHeader(title: 'Your Destiny Reading'),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: AiSourceChip(isLiveAi: widget.result.isLiveAi),
              ),
              const SizedBox(height: 14),
              if (_hasNarrative)
                ..._paragraphs.asMap().entries.map((entry) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 420 + (entry.key * 120)),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 12),
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.cardBase,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardStroke),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.08),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          entry.value,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  );
                })
              else
                ...List.generate(_sections.length, (i) {
                  final visible = i < _visibleSections;
                  final section = _sections[i];
                  return AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSlide(
                      offset: visible ? Offset.zero : const Offset(0, 0.06),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SectionCard(
                          title: section.key,
                          body: section.value,
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              _FollowUps(items: widget.result.followUps),
              const SizedBox(height: 8),
              _ComingSoonCard(onTap: () => context.push('/subscription')),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'New Reading',
                onPressed: () => context.go('/'),
              ),
              const SizedBox(height: 14),
              Text(
                AppStrings.disclaimer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowUps extends StatelessWidget {
  const _FollowUps({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: items
          .map(
            (item) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBase.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardStroke),
              ),
              child: Text(item, style: Theme.of(context).textTheme.bodyMedium),
            ),
          )
          .toList(),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBase,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.softGold.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Palm Destiny Premium',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Dual-hand synthesis and deeper karmic insight — coming soon.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'View details →',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.softGold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

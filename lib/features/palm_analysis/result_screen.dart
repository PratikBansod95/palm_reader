import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/animation_timings.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/colors.dart';
import '../../models/palm_result_model.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/breathing_glow.dart';
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

  List<MapEntry<String, String>> get _sections => [
        MapEntry('Personality', widget.result.personality),
        MapEntry('Life Path', widget.result.lifePath),
        MapEntry('Love', widget.result.love),
        MapEntry('Wealth', widget.result.wealth),
        MapEntry('Challenges', widget.result.challenges),
        MapEntry('Guidance', widget.result.guidance),
      ];

  @override
  void initState() {
    super.initState();
    HapticFeedback.selectionClick();
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
              const SizedBox(height: 12),
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
              AnimatedOpacity(
                opacity: _visibleSections >= _sections.length ? 1 : 0,
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      _FollowUps(items: widget.result.followUps),
                      const SizedBox(height: 12),
                      _PremiumCard(onTap: () => context.push('/subscription')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppStrings.disclaimer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted.withOpacity(0.75),
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

class _PremiumCard extends StatefulWidget {
  const _PremiumCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PremiumCard> createState() => _PremiumCardState();
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
                color: AppColors.cardBase.withOpacity(0.7),
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

class _PremiumCardState extends State<_PremiumCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
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
        final opacity = 0.45 + (_controller.value * 0.3);
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBase,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.softGold.withOpacity(opacity),
            ),
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unlock deeper destiny insights',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Get dual-hand synthesis, compatibility depth, and expanded karmic interpretation.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          BreathingGlow(
            child: PrimaryButton(label: 'Continue to Premium', onPressed: widget.onTap),
          ),
        ],
      ),
    );
  }
}


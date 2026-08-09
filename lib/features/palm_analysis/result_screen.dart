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

  bool get _structured => widget.result.hasStructuredSections;

  List<_ReadingBlock> get _blocks {
    final result = widget.result;
    if (_structured) {
      return [
        if (result.opening.trim().isNotEmpty)
          _ReadingBlock(
            title: 'The First Glimpse',
            body: result.opening,
            icon: Icons.auto_awesome,
            featured: true,
          ),
        if (result.personality.trim().isNotEmpty)
          _ReadingBlock(
            title: 'Your Nature',
            body: result.personality,
            icon: Icons.spa_outlined,
          ),
        if (result.lifePath.trim().isNotEmpty)
          _ReadingBlock(
            title: 'Life Path',
            body: result.lifePath,
            icon: Icons.timeline_outlined,
          ),
        if (result.love.trim().isNotEmpty)
          _ReadingBlock(
            title: 'Love & Bonds',
            body: result.love,
            icon: Icons.favorite_border_rounded,
          ),
        if (result.wealth.trim().isNotEmpty)
          _ReadingBlock(
            title: 'Prosperity',
            body: result.wealth,
            icon: Icons.trending_up_rounded,
          ),
        if (result.challenges.trim().isNotEmpty)
          _ReadingBlock(
            title: 'Gentle Challenges',
            body: result.challenges,
            icon: Icons.waves_rounded,
          ),
        if (result.guidance.trim().isNotEmpty)
          _ReadingBlock(
            title: 'Guidance',
            body: result.guidance,
            icon: Icons.lightbulb_outline_rounded,
          ),
        if (result.blessing.trim().isNotEmpty)
          _ReadingBlock(
            title: 'A Blessing',
            body: result.blessing,
            icon: Icons.brightness_2_outlined,
            featured: true,
          ),
      ];
    }

    return widget.result.fullReading
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => _ReadingBlock(
            title: entry.key == 0 ? 'Your Reading' : 'Continued',
            body: entry.value,
            icon: entry.key == 0
                ? Icons.auto_awesome
                : Icons.menu_book_outlined,
            featured: entry.key == 0,
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    HapticFeedback.selectionClick();
    _timer = Timer.periodic(AnimationTimings.sectionStagger, (timer) {
      if (!mounted) return;
      if (_visibleSections < _blocks.length) {
        setState(() => _visibleSections++);
      } else {
        timer.cancel();
      }
    });
    // Reveal first block immediately.
    _visibleSections = 1;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hand = widget.result.handLabel.trim();

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const GlowingHeader(title: 'Your Destiny Reading'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AiSourceChip(isLiveAi: widget.result.isLiveAi),
                  if (hand.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.softGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.softGold.withValues(alpha: 0.75),
                        ),
                      ),
                      child: Text(
                        '${hand[0].toUpperCase()}${hand.substring(1).toLowerCase()} hand reading',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.softGold,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              ...List.generate(_blocks.length, (index) {
                final visible = index < _visibleSections;
                final block = _blocks[index];
                return AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: visible ? Offset.zero : const Offset(0, 0.05),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: block.featured
                          ? _FeaturedReadingCard(block: block)
                          : SectionCard(
                              title: block.title,
                              body: block.body,
                              icon: block.icon,
                              initiallyExpanded: true,
                            ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
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

class _ReadingBlock {
  const _ReadingBlock({
    required this.title,
    required this.body,
    required this.icon,
    this.featured = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool featured;
}

class _FeaturedReadingCard extends StatelessWidget {
  const _FeaturedReadingCard({required this.block});

  final _ReadingBlock block;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.softGold.withValues(alpha: 0.18),
            AppColors.cardBase,
            AppColors.deepIndigo.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: AppColors.softGold.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(block.icon, color: AppColors.softGold, size: 20),
              const SizedBox(width: 8),
              Text(
                block.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.softGold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            block.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.55,
                  fontSize: 17,
                ),
          ),
        ],
      ),
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

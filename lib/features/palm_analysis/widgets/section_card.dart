import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

class SectionCard extends StatefulWidget {
  const SectionCard({
    required this.title,
    required this.body,
    super.key,
    this.icon,
    this.initiallyExpanded = false,
  });

  final String title;
  final String body;
  final IconData? icon;
  final bool initiallyExpanded;

  @override
  State<SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<SectionCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: DecoratedBox(
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
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: AppColors.softGold.withValues(alpha: 0.9),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(widget.title, style: textTheme.titleLarge),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.softGold.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  sizeCurve: Curves.easeOutCubic,
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Text(
                    widget.body,
                    style: textTheme.bodyMedium?.copyWith(height: 1.45),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondChild: Text(
                    widget.body,
                    style: textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

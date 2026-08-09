import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/primary_button.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const SizedBox(height: 8),
                Text('Palm Destiny Premium', style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Elevated insight for those who want clarity, precision, and depth.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _planCard(
                  context,
                  title: 'Premium Tier',
                  subtitle: 'Coming Soon',
                  features: const [
                    'Dual-hand comparison',
                    'Detailed year forecast',
                    'Relationship compatibility',
                    'Advanced karmic analysis',
                  ],
                  highlighted: true,
                ),
                const SizedBox(height: 14),
                _planCard(
                  context,
                  title: 'Basic Reading',
                  subtitle: 'Current Access',
                  features: const [
                    'Single hand interpretation',
                    'Narrative destiny reading',
                    'Language & hand preferences',
                  ],
                  highlighted: false,
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Coming Soon',
                  breathing: true,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Premium unlocks are coming soon. Your basic reading remains free.',
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
    );
  }

  Widget _planCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<String> features,
    required bool highlighted,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: highlighted
            ? AppColors.cardBase.withValues(alpha: 0.85)
            : AppColors.cardBase,
        border: Border.all(
          color: highlighted
              ? AppColors.softGold.withValues(alpha: 0.85)
              : AppColors.cardStroke,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  blurRadius: 22,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.softGold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $feature',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

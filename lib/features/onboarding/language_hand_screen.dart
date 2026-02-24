import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/colors.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/primary_button.dart';

class LanguageHandScreen extends StatefulWidget {
  const LanguageHandScreen({super.key});

  @override
  State<LanguageHandScreen> createState() => _LanguageHandScreenState();
}

class _LanguageHandScreenState extends State<LanguageHandScreen> {
  String _language = 'English';
  String _hand = 'Right';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AnimatedBackground(
        showMandala: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                Container(
                  height: 128,
                  width: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.softGold.withOpacity(0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Text(AppStrings.appName, style: textTheme.displaySmall),
                const SizedBox(height: 6),
                Text(AppStrings.subtitle, style: textTheme.bodyLarge),
                const SizedBox(height: 34),
                Text('Language', style: textTheme.titleLarge),
                const SizedBox(height: 10),
                _ChoiceRow(
                  options: const ['English', 'Hindi'],
                  selected: _language,
                  onSelected: (v) => setState(() => _language = v),
                ),
                const SizedBox(height: 24),
                Text('Dominant Hand', style: textTheme.titleLarge),
                const SizedBox(height: 10),
                _ChoiceRow(
                  options: const ['Right', 'Left'],
                  selected: _hand,
                  onSelected: (v) => setState(() => _hand = v),
                ),
                const Spacer(flex: 3),
                PrimaryButton(
                  label: 'Begin Reading',
                  breathing: true,
                  onPressed: () => context.go('/capture'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
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
          .map(
            (option) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ChoiceChip(
                  label: Center(child: Text(option)),
                  selected: selected == option,
                  onSelected: (_) => onSelected(option),
                  selectedColor: AppColors.gold,
                  side: const BorderSide(color: AppColors.cardStroke),
                  labelStyle: TextStyle(
                    color: selected == option
                        ? AppColors.midnight
                        : AppColors.textPrimary,
                  ),
                  backgroundColor: AppColors.cardBase,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}


import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          onPrimary: AppColors.midnight,
          secondary: AppColors.softGold,
          surface: AppColors.cardBase,
          onSurface: AppColors.textPrimary,
        ),
        textTheme: AppTypography.textTheme,
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.deepIndigo.withOpacity(0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.cardStroke),
          ),
        ),
      );
}


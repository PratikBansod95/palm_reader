import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

class AppTypography {
  static TextTheme get textTheme => TextTheme(
        displaySmall: GoogleFonts.cormorantGaramond(
          color: AppColors.textPrimary,
          fontSize: 38,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.9,
        ),
        headlineMedium: GoogleFonts.cormorantGaramond(
          color: AppColors.textPrimary,
          fontSize: 29,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.7,
        ),
        titleLarge: GoogleFonts.cormorantGaramond(
          color: AppColors.textPrimary,
          fontSize: 23,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
        bodyLarge: GoogleFonts.dmSans(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.dmSans(
          color: AppColors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        labelLarge: GoogleFonts.dmSans(
          color: AppColors.midnight,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );
}


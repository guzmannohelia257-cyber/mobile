import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const String _family = 'Roboto';

  static TextTheme build() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: _family,
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.05,
        color: AppColors.ink,
      ),
      displayMedium: TextStyle(
        fontFamily: _family,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        height: 1.1,
        color: AppColors.ink,
      ),
      displaySmall: TextStyle(
        fontFamily: _family,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
        color: AppColors.ink,
      ),
      headlineLarge: TextStyle(
        fontFamily: _family,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.2,
        color: AppColors.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: _family,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.25,
        color: AppColors.ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: _family,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
        color: AppColors.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: _family,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.35,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: _family,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
        color: AppColors.ink,
      ),
      titleSmall: TextStyle(
        fontFamily: _family,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.4,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: _family,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.5,
        color: AppColors.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: _family,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
        color: AppColors.inkSubtle,
      ),
      bodySmall: TextStyle(
        fontFamily: _family,
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.45,
        color: AppColors.inkSubtle,
      ),
      labelLarge: TextStyle(
        fontFamily: _family,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        height: 1.2,
        color: AppColors.ink,
      ),
      labelMedium: TextStyle(
        fontFamily: _family,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        height: 1.2,
        color: AppColors.ink,
      ),
      labelSmall: TextStyle(
        fontFamily: _family,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.9,
        height: 1.2,
        color: AppColors.inkMuted,
      ),
    );
  }

  static const TextStyle overline = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: AppColors.inkMuted,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: AppColors.inkSubtle,
  );
}

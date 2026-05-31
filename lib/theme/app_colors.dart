import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color brand = Color(0xFFB11D27);
  static const Color brandDark = Color(0xFF7C1419);
  static const Color brandSoft = Color(0xFFFCE7E9);
  static const Color brandInk = Color(0xFF4A0F14);

  static const Color ink = Color(0xFF18181B);
  static const Color inkSubtle = Color(0xFF52525B);
  static const Color inkMuted = Color(0xFF8A8A93);
  static const Color inkFaint = Color(0xFFB4B4BC);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFFAFAF7);
  static const Color background = Color(0xFFF4F2ED);
  static const Color overlay = Color(0xFFF0EDE6);

  static const Color border = Color(0xFFE7E4DD);
  static const Color borderSubtle = Color(0xFFF0EDE6);
  static const Color borderStrong = Color(0xFFD6D3CB);

  static const Color amber = Color(0xFFB45309);
  static const Color amberSoft = Color(0xFFFEF3C7);
  static const Color forest = Color(0xFF15803D);
  static const Color forestSoft = Color(0xFFDCFCE7);
  static const Color slate = Color(0xFF1F2937);
  static const Color slateSoft = Color(0xFFE5E7EB);
  static const Color indigo = Color(0xFF3730A3);
  static const Color indigoSoft = Color(0xFFE0E7FF);

  static const Color danger = brand;
  static const Color dangerSoft = brandSoft;

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB11D27), Color(0xFF7C1419)],
  );

  static const LinearGradient duskGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1F2937), Color(0xFF0B1220)],
  );

  static List<BoxShadow> shadowSm = [
    BoxShadow(
      color: const Color(0xFF18181B).withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF18181B).withValues(alpha: 0.02),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: const Color(0xFF18181B).withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF18181B).withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: const Color(0xFF18181B).withValues(alpha: 0.08),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: const Color(0xFF18181B).withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
}

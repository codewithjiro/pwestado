import 'package:flutter/material.dart';

/// PWESTADO brand palette: deep emerald, mint, off-white.
abstract final class BrandColors {
  static const emerald900 = Color(0xFF0B3D2E);
  static const emerald700 = Color(0xFF0F5C45);
  static const emerald500 = Color(0xFF1F7A5C);
  static const mint = Color(0xFF8EE3C0);
  static const mintSoft = Color(0xFFDDF5EA);
  static const offWhite = Color(0xFFF7F6F1);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16231E);
  static const inkMuted = Color(0xFF55645E);
  static const outline = Color(0xFFD5DDD8);

  /// Reserved for competitor pins (Phase 03) so they contrast with the site pin.
  static const competitorOrange = Color(0xFFE8772E);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: BrandColors.emerald700)
      .copyWith(
        primary: BrandColors.emerald700,
        onPrimary: Colors.white,
        primaryContainer: BrandColors.mintSoft,
        onPrimaryContainer: BrandColors.emerald900,
        secondary: BrandColors.mint,
        onSecondary: BrandColors.emerald900,
        tertiary: BrandColors.competitorOrange,
        surface: BrandColors.offWhite,
        onSurface: BrandColors.ink,
        onSurfaceVariant: BrandColors.inkMuted,
        surfaceContainerLowest: BrandColors.surfaceRaised,
        outline: BrandColors.outline,
        outlineVariant: BrandColors.outline,
      );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = base.textTheme.apply(
    bodyColor: BrandColors.ink,
    displayColor: BrandColors.emerald900,
  );

  return base.copyWith(
    scaffoldBackgroundColor: BrandColors.offWhite,
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: text.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: BrandColors.surfaceRaised,
      selectedColor: BrandColors.mintSoft,
      side: const BorderSide(color: BrandColors.outline),
      labelStyle: text.labelLarge?.copyWith(color: BrandColors.ink),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 48),
        selectedBackgroundColor: BrandColors.emerald700,
        selectedForegroundColor: Colors.white,
        backgroundColor: BrandColors.surfaceRaised,
        side: const BorderSide(color: BrandColors.outline),
        textStyle: text.labelLarge,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: BrandColors.surfaceRaised,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
  );
}

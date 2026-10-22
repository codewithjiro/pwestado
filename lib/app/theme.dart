import 'package:flutter/material.dart';

/// PWESTADO brand palette: deep emerald, mint, warm off-white.
abstract final class BrandColors {
  static const emerald900 = Color(0xFF0B3D2E);
  static const emerald800 = Color(0xFF0D4A38);
  static const emerald700 = Color(0xFF0F5C45);
  static const emerald500 = Color(0xFF1F7A5C);
  static const emerald300 = Color(0xFF5FB596);
  static const mint = Color(0xFF8EE3C0);
  static const mintSoft = Color(0xFFDDF5EA);
  static const mintWash = Color(0xFFEFFAF5);
  static const offWhite = Color(0xFFF7F6F1);
  static const sand = Color(0xFFEFEDE4);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16231E);
  static const inkMuted = Color(0xFF55645E);
  static const outline = Color(0xFFD5DDD8);
  static const outlineSoft = Color(0xFFE6EBE7);

  /// Competitor pins, so they contrast with the emerald site pin.
  static const competitorOrange = Color(0xFFE8772E);

  /// Warnings and SAMPLE DEMO DATA.
  static const amberWash = Color(0xFFFFF1C2);
  static const amberInk = Color(0xFF6B4A00);
  static const amberEdge = Color(0xFFE2B93B);

  /// Errors and blocked comparisons.
  static const roseWash = Color(0xFFFFF4F2);
  static const roseEdge = Color(0xFFF1C9C2);
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
  static const pill = 999.0;
}

/// Restrained elevation: one soft emerald-tinted shadow for floating
/// surfaces, nothing heavier.
abstract final class AppShadows {
  static const floating = [
    BoxShadow(color: Color(0x1F0B3D2E), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const card = [
    BoxShadow(color: Color(0x0F0B3D2E), blurRadius: 12, offset: Offset(0, 3)),
  ];
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
        secondaryContainer: BrandColors.mintSoft,
        onSecondaryContainer: BrandColors.emerald900,
        tertiary: BrandColors.competitorOrange,
        surface: BrandColors.offWhite,
        onSurface: BrandColors.ink,
        onSurfaceVariant: BrandColors.inkMuted,
        surfaceContainerLowest: BrandColors.surfaceRaised,
        outline: BrandColors.outline,
        outlineVariant: BrandColors.outlineSoft,
      );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = base.textTheme.apply(
    bodyColor: BrandColors.ink,
    displayColor: BrandColors.emerald900,
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );

  return base.copyWith(
    scaffoldBackgroundColor: BrandColors.offWhite,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: BrandColors.emerald900,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: BrandColors.emerald900,
      ),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      bodySmall: text.bodySmall?.copyWith(height: 1.4),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: BrandColors.offWhite,
      foregroundColor: BrandColors.emerald900,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: BrandColors.emerald900,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: buttonShape,
        textStyle: text.labelLarge?.copyWith(fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: buttonShape,
        foregroundColor: BrandColors.emerald700,
        side: const BorderSide(color: BrandColors.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: BrandColors.emerald700,
        shape: buttonShape,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: BrandColors.surfaceRaised,
      selectedColor: BrandColors.emerald700,
      secondarySelectedColor: BrandColors.emerald700,
      side: const BorderSide(color: BrandColors.outline),
      labelStyle: text.labelLarge?.copyWith(color: BrandColors.ink),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 48),
        selectedBackgroundColor: BrandColors.emerald700,
        selectedForegroundColor: Colors.white,
        backgroundColor: BrandColors.surfaceRaised,
        foregroundColor: BrandColors.ink,
        side: const BorderSide(color: BrandColors.outline),
        textStyle: text.labelLarge,
        shape: buttonShape,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: BrandColors.emerald900,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      actionTextColor: BrandColors.mint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    dividerTheme: const DividerThemeData(color: BrandColors.outlineSoft),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: BrandColors.surfaceRaised,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: BrandColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
  );
}

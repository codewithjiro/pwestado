import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fixed PWESTADO brand colors. They do not change with the theme, so use
/// them only where the brand must look identical in light and dark mode:
/// the splash screen, the app icon background, and map pin bitmaps (which
/// carry their own white outline). Everything else uses [AppPalette] via
/// `context.palette`.
abstract final class BrandColors {
  static const emerald900 = Color(0xFF0B3D2E);
  static const emerald800 = Color(0xFF0D4A38);
  static const emerald700 = Color(0xFF0F5C45);
  static const emerald500 = Color(0xFF1F7A5C);
  static const emerald300 = Color(0xFF5FB596);
  static const mint = Color(0xFF8EE3C0);
  static const mintSoft = Color(0xFFDDF5EA);

  /// Competitor pins, so they contrast with the emerald site pin.
  static const competitorOrange = Color(0xFFE8772E);
}

/// Semantic color tokens. Screens ask for a role ("secondary text",
/// "warning container"), never for a raw brand color, so light and dark
/// mode stay consistent.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.heading,
    required this.border,
    required this.borderStrong,
    required this.brand,
    required this.brandFill,
    required this.onBrandFill,
    required this.accent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.accentWash,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.warningBorder,
    required this.danger,
    required this.dangerContainer,
    required this.dangerBorder,
    required this.historical,
    required this.historicalContainer,
    required this.ai,
    required this.aiContainer,
    required this.aiBorder,
    required this.sample,
    required this.sampleContainer,
    required this.sampleBorder,
    required this.sitePin,
    required this.competitor,
    required this.competitorContainer,
    required this.criterion,
    required this.criterionTint,
    required this.shadow,
  });

  /// Page background behind cards.
  final Color background;

  /// Cards, sheets, navigation bar.
  final Color surface;

  /// Surfaces that sit above [surface] (menus, dialogs, floating buttons).
  final Color surfaceElevated;

  /// Quiet inset areas inside cards (formula box, empty slots).
  final Color surfaceMuted;

  final Color textPrimary;
  final Color textSecondary;

  /// Page and card titles.
  final Color heading;

  /// Hairline borders and dividers.
  final Color border;

  /// Input outlines and stronger separators.
  final Color borderStrong;

  /// Brand foreground: icons, links, emphasized numbers.
  final Color brand;

  /// Brand-filled shapes (step dots, icon discs) and [onBrandFill] on them.
  final Color brandFill;
  final Color onBrandFill;

  final Color accent;
  final Color accentContainer;
  final Color onAccentContainer;

  /// Very light brand tint for guidance cards and tags.
  final Color accentWash;

  final Color success;
  final Color successContainer;

  /// Warning text/icon on [warningContainer]. Also used for low confidence.
  final Color warning;
  final Color warningContainer;
  final Color warningBorder;

  final Color danger;
  final Color dangerContainer;
  final Color dangerBorder;

  /// Saved, historical evidence (never refreshed).
  final Color historical;
  final Color historicalContainer;

  /// AI-generated explanations: always visually separate from facts.
  final Color ai;
  final Color aiContainer;
  final Color aiBorder;

  /// SAMPLE DEMO DATA.
  final Color sample;
  final Color sampleContainer;
  final Color sampleBorder;

  /// The selected site in lists and legends.
  final Color sitePin;

  /// Competitor markers in lists and legends.
  final Color competitor;
  final Color competitorContainer;

  /// One strong and one tint color per scoring criterion, in 40/30/30 order.
  final List<Color> criterion;
  final List<Color> criterionTint;

  final Color shadow;

  Color get lowConfidence => warning;
  Color get lowConfidenceContainer => warningContainer;

  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: shadow.withValues(alpha: shadow.a * 0.5),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  List<BoxShadow> get floatingShadow => [
    BoxShadow(color: shadow, blurRadius: 18, offset: const Offset(0, 6)),
  ];

  static const light = AppPalette(
    background: Color(0xFFF7F8F5),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F4F0),
    textPrimary: Color(0xFF172A21),
    textSecondary: Color(0xFF61746A),
    heading: Color(0xFF0B3D2E),
    border: Color(0xFFE0E7E2),
    borderStrong: Color(0xFFC9D4CD),
    brand: Color(0xFF0F5C45),
    brandFill: Color(0xFF0F5C45),
    onBrandFill: Color(0xFF8EE3C0),
    accent: Color(0xFF8EE3C0),
    accentContainer: Color(0xFFDDF5EA),
    onAccentContainer: Color(0xFF0B3D2E),
    accentWash: Color(0xFFEFFAF5),
    success: Color(0xFF1F7A5C),
    successContainer: Color(0xFFDDF5EA),
    warning: Color(0xFF6B4A00),
    warningContainer: Color(0xFFFFF1C2),
    warningBorder: Color(0xFFE2B93B),
    danger: Color(0xFFB3261E),
    dangerContainer: Color(0xFFFFF4F2),
    dangerBorder: Color(0xFFF1C9C2),
    historical: Color(0xFF3D5A80),
    historicalContainer: Color(0xFFE8EEF7),
    ai: Color(0xFF4B3FA0),
    aiContainer: Color(0xFFF1EFFC),
    aiBorder: Color(0xFFD9D3F5),
    sample: Color(0xFF6B4A00),
    sampleContainer: Color(0xFFFFF1C2),
    sampleBorder: Color(0xFFE2B93B),
    sitePin: Color(0xFF0F5C45),
    competitor: Color(0xFFC25E1C),
    competitorContainer: Color(0xFFFCE9DC),
    criterion: [Color(0xFF0B3D2E), Color(0xFF1F7A5C), Color(0xFF5FB596)],
    criterionTint: [Color(0xFFD3E6DE), Color(0xFFDDF5EA), Color(0xFFEFFAF5)],
    shadow: Color(0x1F0B3D2E),
  );

  static const dark = AppPalette(
    background: Color(0xFF101916),
    surface: Color(0xFF1B2922),
    surfaceElevated: Color(0xFF24362D),
    surfaceMuted: Color(0xFF15211B),
    textPrimary: Color(0xFFF4F8F5),
    textSecondary: Color(0xFFB4C7BB),
    heading: Color(0xFFF4F8F5),
    border: Color(0xFF34483D),
    borderStrong: Color(0xFF486052),
    brand: Color(0xFFA8E6C5),
    brandFill: Color(0xFFA8E6C5),
    onBrandFill: Color(0xFF0B3D2E),
    accent: Color(0xFFA8E6C5),
    accentContainer: Color(0xFF234434),
    onAccentContainer: Color(0xFFD3F4E2),
    accentWash: Color(0xFF18271F),
    success: Color(0xFF85DBB2),
    successContainer: Color(0xFF1E3A2C),
    warning: Color(0xFFF2D27C),
    warningContainer: Color(0xFF392E12),
    warningBorder: Color(0xFF7A6224),
    danger: Color(0xFFFFB4AB),
    dangerContainer: Color(0xFF3B1F1C),
    dangerBorder: Color(0xFF6E3A33),
    historical: Color(0xFFADC6EA),
    historicalContainer: Color(0xFF1F2B3B),
    ai: Color(0xFFC9C0FF),
    aiContainer: Color(0xFF242139),
    aiBorder: Color(0xFF3F3A68),
    sample: Color(0xFFF2D27C),
    sampleContainer: Color(0xFF392E12),
    sampleBorder: Color(0xFF8A6E26),
    sitePin: Color(0xFFA8E6C5),
    competitor: Color(0xFFF7A46B),
    competitorContainer: Color(0xFF3D2A1C),
    criterion: [Color(0xFFA8E6C5), Color(0xFF6FCFA2), Color(0xFF4FA683)],
    criterionTint: [Color(0xFF2A4136), Color(0xFF243B30), Color(0xFF20352B)],
    shadow: Color(0x66000000),
  );

  @override
  AppPalette copyWith() => this;

  /// Theme changes switch palettes instantly; interpolating dozens of
  /// tokens per frame buys nothing visible.
  @override
  AppPalette lerp(covariant AppPalette? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
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

/// Font families. Both are bundled under the SIL Open Font License.
abstract final class AppFonts {
  /// Branding, page titles, headings and key metrics.
  static const display = 'PlusJakartaSans';

  /// Paragraphs, forms, business records, buttons and navigation labels.
  static const body = 'Inter';

  /// Aligned digits for scores, distances and counts.
  static const tabular = [FontFeature.tabularFigures()];
}

/// The type scale. Roles map onto Material's text theme so every widget
/// picks them up:
///
/// | Role            | Style           | Font            |
/// |-----------------|-----------------|-----------------|
/// | Display / hero  | displaySmall    | Plus Jakarta 800|
/// | Page title      | headlineSmall   | Plus Jakarta 800|
/// | Section heading | titleLarge      | Plus Jakarta 700|
/// | Card title      | titleMedium     | Plus Jakarta 700|
/// | Body            | bodyMedium      | Inter 400       |
/// | Supporting text | bodySmall       | Inter 400       |
/// | Button          | labelLarge      | Inter 600       |
/// | Caption         | labelSmall      | Inter 600       |
TextTheme buildTextTheme(AppPalette p) {
  TextStyle display(
    double size,
    FontWeight weight,
    double height, {
    double spacing = 0,
  }) => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: p.heading,
  );
  TextStyle body(
    double size,
    FontWeight weight,
    double height, {
    double spacing = 0,
    Color? color,
  }) => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color ?? p.textPrimary,
  );

  return TextTheme(
    displayLarge: display(48, FontWeight.w800, 1.1, spacing: -1),
    displayMedium: display(40, FontWeight.w800, 1.1, spacing: -0.8),
    displaySmall: display(34, FontWeight.w800, 1.12, spacing: -0.6),
    headlineLarge: display(30, FontWeight.w800, 1.2, spacing: -0.5),
    headlineMedium: display(27, FontWeight.w800, 1.2, spacing: -0.4),
    headlineSmall: display(24, FontWeight.w800, 1.25, spacing: -0.3),
    titleLarge: display(20, FontWeight.w700, 1.3, spacing: -0.2),
    titleMedium: display(16.5, FontWeight.w700, 1.35, spacing: -0.1),
    titleSmall: body(14.5, FontWeight.w600, 1.4),
    bodyLarge: body(16, FontWeight.w400, 1.5),
    bodyMedium: body(14.5, FontWeight.w400, 1.5),
    bodySmall: body(13, FontWeight.w400, 1.45, color: p.textSecondary),
    labelLarge: body(14.5, FontWeight.w600, 1.3, spacing: 0.1),
    labelMedium: body(12.5, FontWeight.w600, 1.3, spacing: 0.1),
    labelSmall: body(11.5, FontWeight.w600, 1.3, spacing: 0.4),
  );
}

ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final p = dark ? AppPalette.dark : AppPalette.light;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: BrandColors.emerald700,
        brightness: brightness,
      ).copyWith(
        primary: p.brandFill,
        // White on emerald reads best for button labels in light mode.
        onPrimary: dark ? p.onBrandFill : Colors.white,
        primaryContainer: p.accentContainer,
        onPrimaryContainer: p.onAccentContainer,
        secondary: p.accent,
        onSecondary: BrandColors.emerald900,
        secondaryContainer: p.accentContainer,
        onSecondaryContainer: p.onAccentContainer,
        tertiary: p.competitor,
        error: p.danger,
        errorContainer: p.dangerContainer,
        surface: p.background,
        onSurface: p.textPrimary,
        onSurfaceVariant: p.textSecondary,
        surfaceContainerLowest: p.surface,
        surfaceContainerLow: p.surface,
        surfaceContainer: p.surface,
        surfaceContainerHigh: p.surfaceElevated,
        surfaceContainerHighest: p.surfaceElevated,
        outline: p.borderStrong,
        outlineVariant: p.border,
        shadow: p.shadow,
      );

  final text = buildTextTheme(p);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );
  final overlay = dark
      ? SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: p.surface,
          systemNavigationBarIconBrightness: Brightness.light,
        )
      : SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: p.surface,
          systemNavigationBarIconBrightness: Brightness.dark,
        );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: AppFonts.body,
    textTheme: text,
    extensions: [p],
    scaffoldBackgroundColor: p.background,
    canvasColor: p.surface,
    iconTheme: IconThemeData(color: p.textSecondary),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.heading,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      systemOverlayStyle: overlay,
      titleTextStyle: text.headlineSmall,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: buttonShape,
        textStyle: text.labelLarge?.copyWith(fontSize: 15.5),
        disabledBackgroundColor: p.surfaceMuted,
        disabledForegroundColor: p.textSecondary.withValues(alpha: 0.75),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: buttonShape,
        foregroundColor: p.brand,
        textStyle: text.labelLarge,
        side: BorderSide(color: p.borderStrong),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: p.brand,
        textStyle: text.labelLarge,
        shape: buttonShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: text.bodyMedium?.copyWith(color: p.textSecondary),
      hintStyle: text.bodyLarge?.copyWith(color: p.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: p.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: p.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: p.brand, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.brandFill,
      side: BorderSide(color: p.borderStrong),
      labelStyle: text.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 48),
        selectedBackgroundColor: p.brandFill,
        selectedForegroundColor: scheme.onPrimary,
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        side: BorderSide(color: p.borderStrong),
        textStyle: text.labelLarge,
        shape: buttonShape,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.accentContainer,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelSmall?.copyWith(
          fontSize: 11.5,
          letterSpacing: 0.6,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? p.heading
              : p.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? p.onAccentContainer
              : p.textSecondary,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? p.surfaceElevated : BrandColors.emerald900,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: dark ? p.textPrimary : Colors.white,
      ),
      actionTextColor: dark ? p.accent : BrandColors.mint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.brand,
      linearTrackColor: p.accentContainer,
    ),
    dividerTheme: DividerThemeData(color: p.border),
    listTileTheme: ListTileThemeData(
      iconColor: p.brand,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.borderStrong,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surfaceElevated,
      surfaceTintColor: Colors.transparent,
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: p.competitor,
      textColor: dark ? BrandColors.emerald900 : Colors.white,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? p.surfaceElevated : BrandColors.emerald900,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: text.labelMedium?.copyWith(
        color: dark ? p.textPrimary : Colors.white,
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The app's standard content card: surface color, 16 px radius, hairline
/// border, one soft shadow. A [Material] so ink splashes and expansion tiles
/// render. Colors default to the current theme's palette.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.borderColor,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.md);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: elevated ? palette.cardShadow : null,
      ),
      child: Material(
        color: color ?? palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor ?? palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Card title row: tinted icon tile, title, optional subtitle and trailing
/// action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconBackground,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconBackground;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBackground ?? palette.accentContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: iconColor ?? palette.brand, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null)
                Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Visual tones shared by pills and notes, so "sample", "AI" and
/// "historical" look the same everywhere.
enum Tone { brand, warning, danger, sample, ai, historical, neutral }

extension ToneColors on AppPalette {
  /// (background, foreground, border) for [tone].
  (Color, Color, Color) toneColors(Tone tone) => switch (tone) {
    Tone.brand => (accentContainer, onAccentContainer, accent),
    Tone.warning => (warningContainer, warning, warningBorder),
    Tone.danger => (dangerContainer, danger, dangerBorder),
    Tone.sample => (sampleContainer, sample, sampleBorder),
    Tone.ai => (aiContainer, ai, aiBorder),
    Tone.historical => (historicalContainer, historical, historicalContainer),
    Tone.neutral => (surfaceMuted, textSecondary, border),
  };
}

/// Small rounded label with an icon.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    this.tone = Tone.brand,
    this.background,
    this.foreground,
    this.uppercase = false,
  });

  final String label;
  final IconData icon;
  final Tone tone;
  final Color? background;
  final Color? foreground;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final (toneBackground, toneForeground, _) = context.palette.toneColors(
      tone,
    );
    final fg = foreground ?? toneForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? toneBackground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                letterSpacing: uppercase ? 0.6 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum NoteTone { neutral, positive, warning, danger }

/// Inline callout for verdicts, warnings and errors.
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.icon,
    required this.lines,
    this.title,
    this.tone = NoteTone.neutral,
  });

  final IconData icon;
  final String? title;
  final List<String> lines;
  final NoteTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;
    final (background, border, iconColor, textColor) = switch (tone) {
      NoteTone.neutral => (p.surfaceMuted, p.border, p.brand, p.textPrimary),
      NoteTone.positive => (
        p.accentContainer,
        p.accent,
        p.brand,
        p.onAccentContainer,
      ),
      NoteTone.warning => (
        p.warningContainer,
        p.warningBorder,
        p.warning,
        p.warning,
      ),
      NoteTone.danger => (
        p.dangerContainer,
        p.dangerBorder,
        p.danger,
        p.textPrimary,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: textColor,
                    ),
                  ),
                for (final line in lines)
                  Text(
                    line,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercase eyebrow label above a group of controls, with an optional
/// step number.
class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel(this.text, {super.key, this.step});

  final String text;
  final int? step;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          if (step != null) ...[
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.brandFill,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$step',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.onBrandFill,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: palette.brand,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle? mutedSmall(BuildContext context) => Theme.of(
  context,
).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary);

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The app's standard content card: white, 16 px radius, hairline border,
/// one soft shadow. A [Material] so ink splashes and expansion tiles render.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = BrandColors.surfaceRaised,
    this.borderColor = BrandColors.outlineSoft,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: elevated ? AppShadows.card : null,
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor),
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
    this.iconBackground = BrandColors.mintSoft,
    this.iconColor = BrandColors.emerald700,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BrandColors.inkMuted,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Small rounded label with an icon.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    this.background = BrandColors.mintSoft,
    this.foreground = BrandColors.emerald900,
    this.uppercase = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
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
    final (background, border, iconColor, textColor) = switch (tone) {
      NoteTone.neutral => (
        BrandColors.offWhite,
        BrandColors.outline,
        BrandColors.emerald700,
        BrandColors.ink,
      ),
      NoteTone.positive => (
        BrandColors.mintSoft,
        BrandColors.mint,
        BrandColors.emerald700,
        BrandColors.ink,
      ),
      NoteTone.warning => (
        BrandColors.amberWash,
        BrandColors.amberEdge,
        BrandColors.amberInk,
        BrandColors.amberInk,
      ),
      NoteTone.danger => (
        BrandColors.roseWash,
        BrandColors.roseEdge,
        theme.colorScheme.error,
        BrandColors.ink,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          if (step != null) ...[
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: BrandColors.emerald900,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$step',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: BrandColors.mint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: BrandColors.emerald700,
              fontWeight: FontWeight.w800,
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
).textTheme.bodySmall?.copyWith(color: BrandColors.inkMuted);

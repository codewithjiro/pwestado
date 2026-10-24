import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'surfaces.dart';

/// Standard layout for the ANALYZE, COMPARE and SAVED tabs: a branded app
/// bar with a one-line purpose, then one scrolling column of cards.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: BrandColors.offWhite,
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: AppSpacing.lg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BrandColors.inkMuted,
              ),
            ),
          ],
        ),
        actions: actions,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: children,
      ),
    );
  }
}

/// "What to do next" card for a missing prerequisite, with one clear action.
class GuidanceCard extends StatelessWidget {
  const GuidanceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.step,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// Optional step number shown before the title.
  final int? step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: BrandColors.mintWash,
      borderColor: BrandColors.mintSoft,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: BrandColors.emerald700,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: BrandColors.mint, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  step == null ? title : 'Step $step · $title',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: theme.textTheme.bodyMedium),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

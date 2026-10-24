import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/explore/presentation/widgets/about_sheet.dart';
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
    return Scaffold(
      appBar: buildTabAppBar(
        context,
        title: title,
        subtitle: subtitle,
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

/// The shared tab header: page title, a one-line purpose, the tab's own
/// actions, and the About & appearance entry point.
PreferredSizeWidget buildTabAppBar(
  BuildContext context, {
  required String title,
  required String subtitle,
  List<Widget>? actions,
}) {
  final theme = Theme.of(context);
  return AppBar(
    toolbarHeight: 72,
    titleSpacing: AppSpacing.lg,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ],
    ),
    actions: [
      ...?actions,
      IconButton(
        tooltip: AboutCopy.openTooltip,
        icon: const Icon(Icons.tune_rounded),
        onPressed: () => showAboutSheet(context),
      ),
      const SizedBox(width: AppSpacing.xs),
    ],
  );
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
      color: context.palette.accentWash,
      borderColor: context.palette.accentContainer,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.palette.brand,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: context.palette.onBrandFill, size: 20),
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

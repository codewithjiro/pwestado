import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Plain-language summary of what PWESTADO does and the limits of its data.
Future<void> showAboutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _AboutSheet(),
  );
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About PWESTADO', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A pitch-stage prototype that helps you explore candidate '
              'business sites, see nearby businesses mapped in '
              'OpenStreetMap, and compare two locations.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _Point(
              icon: Icons.map_outlined,
              title: 'Map',
              body:
                  'Rendered by Mapbox. Mapbox draws the map; it is not the '
                  'source of business listings.',
            ),
            const _Point(
              icon: Icons.storefront_outlined,
              title: 'Business listings',
              body:
                  'Fetched from OpenStreetMap only when you tap search. '
                  'Mapped records can be incomplete or out of date.',
            ),
            const _Point(
              icon: Icons.calculate_outlined,
              title: 'Scores',
              body:
                  'A transparent heuristic with a visible formula. Not a '
                  'measure of foot traffic, demand, or profit.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BrandColors.emerald700),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: BrandColors.inkMuted,
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

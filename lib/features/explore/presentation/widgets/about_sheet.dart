import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../app/theme_mode_controller.dart';

abstract final class AboutCopy {
  static const title = 'About PWESTADO';
  static const openTooltip = 'About & appearance';
  static const appearance = 'Appearance';
  static const appearanceHint =
      'System follows your phone’s light or dark setting.';
  static const tagline = 'Ang tamang pwesto, simula ng negosyo.';
  static const intro =
      'PWESTADO helps you explore possible business locations, see nearby '
      'businesses listed on OpenStreetMap, and compare two spots before you '
      'decide.';
  static const licenses = 'Open-source licenses';
}

/// About PWESTADO, its data sources, and the appearance setting.
Future<void> showAboutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Above the bottom navigation bar, not inside the current tab.
    useRootNavigator: true,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AboutCopy.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(
              AboutCopy.tagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.brand,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(AboutCopy.intro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            const AppearanceSelector(),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Where the data comes from',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const _Point(
              icon: Icons.map_outlined,
              title: 'Map',
              body:
                  'Drawn by Mapbox. Mapbox shows the map; it is not where the '
                  'business list comes from.',
            ),
            const _Point(
              icon: Icons.storefront_outlined,
              title: 'Nearby businesses',
              body:
                  'Fetched from OpenStreetMap (via the Overpass API) only when '
                  'you tap search. Some businesses may not be listed or may '
                  'have closed, and the map can’t tell if a place is busy. '
                  'Data © OpenStreetMap contributors (ODbL).',
            ),
            const _Point(
              icon: Icons.calculate_outlined,
              title: 'Suitability score',
              body:
                  'A simple, transparent formula (40% competition, 30% nearby '
                  'helpful places, 30% mapped roads). It does not measure foot '
                  'traffic, demand, sales or profit.',
            ),
            const _Point(
              icon: Icons.auto_awesome_outlined,
              title: 'AI Insights',
              body:
                  'Optional. Only runs when you tap “Explain this result”, and '
                  'only sees the map evidence on screen. It summarizes the '
                  'analysis; it never changes the score or guarantees '
                  'business success.',
            ),
            const _Point(
              icon: Icons.image_outlined,
              title: 'Photos',
              body:
                  'Shown only when a business’s OpenStreetMap record links a '
                  'freely licensed Wikimedia Commons image. Credits appear '
                  'with each photo. Other businesses show a category '
                  'illustration.',
            ),
            const _Point(
              icon: Icons.bookmarks_outlined,
              title: 'Saved analyses',
              body:
                  'Kept only on this phone, and only when you tap Save. They '
                  'keep their original evidence and dates and are never '
                  'updated automatically.',
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'PWESTADO',
                ),
                icon: const Icon(Icons.description_outlined, size: 20),
                label: const Text(AboutCopy.licenses),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// System / Light / Dark, saved across restarts.
class AppearanceSelector extends ConsumerWidget {
  const AppearanceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AboutCopy.appearance, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('System'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) =>
              ref.read(themeModeControllerProvider.notifier).select(s.single),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(AboutCopy.appearanceHint, style: theme.textTheme.bodySmall),
      ],
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
          Icon(icon, color: context.palette.brand),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/age.dart';
import '../../../shared/widgets/category_art.dart';
import '../../comparison/domain/site_comparison.dart';
import '../../comparison/state/comparison_controller.dart';
import '../../explore/state/explore_controller.dart';
import '../data/saved_analysis_repository.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../../shared/widgets/tab_page.dart';
import '../../places/state/place_providers.dart';
import '../domain/saved_analysis.dart';
import '../state/saved_analyses_controller.dart';
import 'saved_widgets.dart';

/// Analyses the user saved on this device, newest first. Opening one reads
/// local storage only; nothing here contacts Overpass.
class SavedAnalysesScreen extends ConsumerWidget {
  const SavedAnalysesScreen({super.key});

  static const title = 'Saved';
  static const subtitle = 'Your analyses, stored on this phone · works offline';
  static const emptyTitle = 'No saved analyses yet';
  static const historicalNote =
      'Historical results stored on this device. They keep the evidence and '
      'retrieval times from when they were saved and are never refreshed, '
      'so they may not match current businesses.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savedAnalysesControllerProvider);
    final controller = ref.read(savedAnalysesControllerProvider.notifier);

    final Widget body;
    if (state.loading && state.items.isEmpty) {
      body = const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading saved analyses',
        ),
      );
    } else if (state.error != null && state.items.isEmpty) {
      body = _Message(
        icon: Icons.sd_card_alert_outlined,
        title: 'Saved analyses are unavailable',
        message: state.error!,
        action: FilledButton.tonalIcon(
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    } else if (state.items.isEmpty) {
      body = const _Message(
        icon: Icons.bookmarks_outlined,
        title: emptyTitle,
        message:
            'Analyze a site, then tap "Save analysis" to keep its score and '
            'evidence here. Nothing is saved unless you ask.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const InfoNote(
              icon: Icons.history_toggle_off,
              lines: [historicalNote],
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final item in state.items) ...[
              _SavedTile(summary: item),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      );
    }

    // A bottom-navigation tab: no back arrow.
    return Scaffold(
      appBar: buildTabAppBar(context, title: title, subtitle: subtitle),
      body: body,
    );
  }
}

class _SavedTile extends ConsumerWidget {
  const _SavedTile({required this.summary});

  final SavedAnalysisSummary summary;

  /// A place name only if this session already looked it up (no request:
  /// the list must open offline and without network traffic); otherwise
  /// the stored "how chosen" label. Place names are never stored.
  static String _placeText(WidgetRef ref, SavedAnalysisSummary summary) {
    final lat = summary.latitude;
    final lon = summary.longitude;
    final cached = lat == null || lon == null
        ? null
        : ref.read(placeRepositoryProvider).cachedLabel((
            latitude: lat,
            longitude: lon,
          ));
    return cached?.title ?? summary.siteLabel ?? 'Saved location';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = mutedSmall(context);
    final category = summary.category;
    final savedAt = summary.savedAt;

    final deleteButton = IconButton(
      tooltip: 'Delete saved analysis',
      icon: const Icon(Icons.delete_outline),
      color: context.palette.textSecondary,
      onPressed: () => deleteSavedWithUndo(context, ref, summary.id),
    );

    if (!summary.isReadable || category == null) {
      return AppCard(
        color: context.palette.dangerContainer,
        borderColor: context.palette.dangerBorder,
        elevated: false,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(Icons.broken_image_outlined, color: theme.colorScheme.error),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unreadable saved record',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    'This record is damaged and cannot be shown. Nothing '
                    'was guessed for it.'
                    '${savedAt == null ? '' : ' Saved ${formatSavedDate(context, savedAt)}.'}',
                    style: muted,
                  ),
                ],
              ),
            ),
            deleteButton,
          ],
        ),
      );
    }

    final total = summary.total;
    final retrievedAt = summary.retrievedAt!;
    return Dismissible(
      key: ValueKey('saved-${summary.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) => deleteSavedWithUndo(context, ref, summary.id),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => context.go(AppRoutes.savedDetail(summary.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryArt(category: category, size: 48),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _placeText(ref, summary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            '${category.label} · within '
                            '${summary.radius!.label}',
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _ScoreBadge(total: total),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    SavedSourceBadge(source: summary.source!),
                    const HistoricalPill(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Saved ${formatSavedDate(context, savedAt!)} · data from '
                  '${formatAge(DateTime.now().difference(retrievedAt))} ago',
                  style: muted,
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          context.go(AppRoutes.savedDetail(summary.id)),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Open'),
                    ),
                    PopupMenuButton<CompareSlot>(
                      tooltip: 'Compare this analysis',
                      onSelected: (slot) =>
                          _compare(context, ref, summary.id, slot),
                      itemBuilder: (context) => [
                        for (final slot in CompareSlot.values)
                          PopupMenuItem(
                            value: slot,
                            child: Text('Compare as ${slot.title}'),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.compare_arrows_rounded,
                              size: 18,
                              color: context.palette.brand,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Compare',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: context.palette.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    deleteButton,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Loads the full record (local, offline), aligns the search settings
  /// with it, puts it in [slot] and opens COMPARE.
  static Future<void> _compare(
    BuildContext context,
    WidgetRef ref,
    int id,
    CompareSlot slot,
  ) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref.read(savedAnalysisRepositoryProvider).load(id);
      final query = saved.analysis.competitors.query;
      ref
          .read(exploreControllerProvider.notifier)
          .applySettings(query.category, query.radius);
      ref.read(comparisonControllerProvider.notifier).loadSaved(slot, saved);
      router.go(AppRoutes.compare);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${slot.title} now holds this saved analysis '
              '(${settingsLabel(query)}).',
            ),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Couldn’t open this saved analysis.')),
        );
    }
  }
}

/// The saved total in a soft rounded badge with aligned digits, or
/// "No score" when the record had insufficient evidence.
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.total});

  final double? total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final total = this.total;
    return Container(
      constraints: const BoxConstraints(minWidth: 60),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: total == null ? palette.surfaceMuted : palette.accentWash,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: total == null ? palette.border : palette.accentContainer,
        ),
      ),
      child: total == null
          ? Text(
              'No score',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: palette.textSecondary,
              ),
            )
          : Semantics(
              label: 'Saved score ${total.round()} out of 100',
              excludeSemantics: true,
              child: Column(
                children: [
                  Text(
                    '${total.round()}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFeatures: AppFonts.tabular,
                      height: 1.1,
                    ),
                  ),
                  Text('of 100', style: theme.textTheme.labelSmall),
                ],
              ),
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.palette.accentContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: context.palette.brand),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

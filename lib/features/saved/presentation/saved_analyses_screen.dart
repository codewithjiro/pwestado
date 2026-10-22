import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/age.dart';
import '../../../shared/widgets/surfaces.dart';
import '../domain/saved_analysis.dart';
import '../state/saved_analyses_controller.dart';
import 'saved_widgets.dart';

/// Analyses the user saved on this device, newest first. Opening one reads
/// local storage only; nothing here contacts Overpass.
class SavedAnalysesScreen extends ConsumerWidget {
  const SavedAnalysesScreen({super.key});

  static const title = 'Saved analyses';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        leading: IconButton(
          tooltip: 'Back to map',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.explore),
        ),
      ),
      body: body,
    );
  }
}

class _SavedTile extends ConsumerWidget {
  const _SavedTile({required this.summary});

  final SavedAnalysisSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = mutedSmall(context);
    final category = summary.category;
    final savedAt = summary.savedAt;

    final deleteButton = IconButton(
      tooltip: 'Delete saved analysis',
      icon: const Icon(Icons.delete_outline),
      color: BrandColors.inkMuted,
      onPressed: () => deleteSavedWithUndo(context, ref, summary.id),
    );

    if (!summary.isReadable || category == null) {
      return AppCard(
        color: BrandColors.roseWash,
        borderColor: BrandColors.roseEdge,
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
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => deleteSavedWithUndo(context, ref, summary.id),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => context.push(AppRoutes.savedDetail(summary.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: BrandColors.mintSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(category.icon, color: BrandColors.emerald700),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${category.label} · ${summary.radius!.label}',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '${summary.coordinatesLabel} · ${summary.siteLabel}',
                        style: muted,
                      ),
                      const SizedBox(height: AppSpacing.xs),
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
                        'Saved ${formatSavedDate(context, savedAt!)}',
                        style: muted,
                      ),
                      Text(
                        'Evidence retrieved '
                        '${formatSavedDate(context, retrievedAt)} '
                        '(${formatAge(DateTime.now().difference(retrievedAt))} '
                        'ago)',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (total != null)
                      Semantics(
                        label: 'Saved score ${total.round()} out of 100',
                        excludeSemantics: true,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${total.round()}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: BrandColors.emerald900,
                                ),
                              ),
                              TextSpan(text: '/100', style: muted),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: 72,
                        child: Text(
                          'Insufficient data',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: BrandColors.inkMuted,
                          ),
                        ),
                      ),
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
                decoration: const BoxDecoration(
                  color: BrandColors.mintSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: BrandColors.emerald700),
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
                  color: BrandColors.inkMuted,
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

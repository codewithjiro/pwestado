import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/elapsed_wait.dart';
import '../../../shared/widgets/surfaces.dart';
import '../domain/competitors.dart';
import '../state/competitor_controller.dart';
import 'competitor_results.dart';
import 'source_labels.dart';

/// The full competitor list (with its loading, empty, error and sample
/// states) in a draggable modal sheet.
Future<void> showCompetitorListSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.palette.background,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Text(
            CompetitorSummary.listTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const CompetitorResults(),
        ],
      ),
    ),
  );
}

/// One-glance outcome of the competitor search: count and data source with
/// "View list", progress with Cancel, or the failure with "Try again".
/// [compact] drops the card frame for use inside the map's control card.
class CompetitorSummary extends ConsumerWidget {
  const CompetitorSummary({super.key, this.compact = false});

  static const listTitle = 'Nearby competitors';
  static const viewList = 'View list';

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(competitorControllerProvider);
    final controller = ref.read(competitorControllerProvider.notifier);
    final theme = Theme.of(context);
    final muted = mutedSmall(context);

    final viewListButton = TextButton.icon(
      onPressed: () => showCompetitorListSheet(context),
      icon: const Icon(Icons.list_alt, size: 18),
      label: const Text(viewList),
    );

    final Widget content;
    switch (state.status) {
      case CompetitorStatus.idle:
        return const SizedBox.shrink();
      case CompetitorStatus.loading:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Looking for nearby businesses…',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text('This can take up to a minute.', style: muted),
                      const ElapsedWait(),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: controller.cancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const LinearProgressIndicator(
              semanticsLabel: 'Looking for nearby businesses',
            ),
          ],
        );
      case CompetitorStatus.error:
        final (title, _, icon) = describeOverpassFailure(
          state.failure!,
          state.statusCode,
        );
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      Text(
                        'The search didn’t finish, so nothing is shown. '
                        'Try again, or tap Details for other options.',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                TextButton(
                  onPressed: () => showCompetitorListSheet(context),
                  child: const Text('Details'),
                ),
                FilledButton.tonal(
                  onPressed: controller.search,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ],
        );
      case CompetitorStatus.empty ||
          CompetitorStatus.success ||
          CompetitorStatus.sample:
        final result = state.result!;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CompetitorDot(),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _countText(result),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SourceBadge(source: result.source),
                Text(
                  result.source == DataSource.sample
                      ? 'Fictional, not real businesses'
                      : 'OpenStreetMap · may be incomplete',
                  style: muted,
                ),
              ],
            ),
            // Own line, so long counts and large fonts never squeeze it.
            Align(alignment: Alignment.centerRight, child: viewListButton),
          ],
        );
    }

    if (compact) return content;
    return AppCard(child: content);
  }

  static String _countText(CompetitorResult result) {
    final query = result.query;
    if (result.isEmpty) {
      return 'No ${query.category.label} businesses listed on the map '
          'within ${query.radius.label}';
    }
    final count = '${result.count}${result.possiblyTruncated ? '+' : ''}';
    return '$count ${query.category.label} '
        '${result.count == 1 ? 'business' : 'businesses'} found within '
        '${query.radius.label}';
  }
}

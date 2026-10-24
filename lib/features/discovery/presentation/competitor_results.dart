import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/elapsed_wait.dart';
import '../../../core/utils/geo.dart';
import '../../../core/models/business_category.dart';
import '../domain/competitors.dart';
import 'business_thumbnail.dart';
import '../state/competitor_controller.dart';
import 'competitor_details_sheet.dart';
import 'source_labels.dart';

/// Highlights [business] on the map and opens its details.
void openCompetitorDetails(
  BuildContext context,
  WidgetRef ref,
  NearbyBusiness business,
) {
  final state = ref.read(competitorControllerProvider);
  final result = state.result;
  if (result == null) return;
  ref.read(competitorControllerProvider.notifier).selectBusiness(business.key);
  showCompetitorDetailsSheet(context, business: business, result: result);
}

/// Loading, result, empty, error, and sample states of the competitor
/// search, placed under the search button. Returns plain children so it can
/// live inside the panel's scroll view.
class CompetitorResults extends ConsumerStatefulWidget {
  const CompetitorResults({super.key});

  static const emptyMessage =
      'No businesses found on the map within this radius.';
  static const coverageNote =
      'Only businesses listed on OpenStreetMap appear. Some may be missing '
      'or out of date, so this isn’t a complete list and doesn’t show how '
      'busy they are.';
  static const attribution =
      'Business data © OpenStreetMap contributors (ODbL), via the Overpass '
      'API.';

  static const sampleNote =
      'The businesses above are fictional sample data. Live searches use '
      'OpenStreetMap data (© OpenStreetMap contributors, ODbL) via the '
      'Overpass API.';

  /// Long lists are cut to this many rows until "Show all" is tapped.
  static const initialRows = 30;

  @override
  ConsumerState<CompetitorResults> createState() => _CompetitorResultsState();
}

class _CompetitorResultsState extends ConsumerState<CompetitorResults> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(competitorControllerProvider.select((s) => s.result), (_, _) {
      if (_showAll) setState(() => _showAll = false);
    });
    final state = ref.watch(competitorControllerProvider);
    final controller = ref.read(competitorControllerProvider.notifier);

    final body = switch (state.status) {
      CompetitorStatus.idle => const SizedBox.shrink(),
      CompetitorStatus.loading => _Loading(onCancel: controller.cancel),
      CompetitorStatus.error => _ErrorView(
        failure: state.failure!,
        statusCode: state.statusCode,
        onRetry: controller.search,
        onSample: controller.showSample,
      ),
      CompetitorStatus.empty => _EmptyView(
        result: state.result!,
        onRefresh: () => controller.search(forceRefresh: true),
      ),
      CompetitorStatus.success || CompetitorStatus.sample => _ResultList(
        state: state,
        showAll: _showAll,
        onShowAll: () => setState(() => _showAll = true),
        onOpen: (business) => openCompetitorDetails(context, ref, business),
        onRefresh: () => controller.search(forceRefresh: true),
        onLeaveSample: controller.search,
      ),
    };

    final hasOutcome = state.status != CompetitorStatus.idle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasOutcome) const SizedBox(height: AppSpacing.lg),
        body,
        const SizedBox(height: AppSpacing.lg),
        _CoverageNote(sample: state.status == CompetitorStatus.sample),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Looking for nearby businesses…',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: context.palette.accentContainer,
              semanticsLabel: 'Searching OpenStreetMap',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const ElapsedWait(),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'We use a free public map server, so this can take up to a '
            'minute. Thanks for waiting!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ),
        ],
      ),
    );
  }
}

/// Title, message, and icon for a failed Overpass request.
(String, String, IconData) describeOverpassFailure(
  CompetitorFailure failure,
  int? statusCode,
) => switch (failure) {
  CompetitorFailure.timeout => (
    'The search took too long',
    'The map data server is slow right now. Please try again in a moment.',
    Icons.hourglass_empty,
  ),
  CompetitorFailure.rateLimited => (
    'Too many searches right now',
    'The free map data server is limiting requests. Please wait a minute, '
        'then try again.',
    Icons.front_hand_outlined,
  ),
  CompetitorFailure.serverBusy => (
    'The map data server is busy',
    'It couldn’t run the search just now. This usually clears up in a few '
        'seconds, so try again shortly.',
    Icons.dns_outlined,
  ),
  CompetitorFailure.network => (
    'No internet connection',
    'We couldn’t reach the map data server. Check your connection and try '
        'again.',
    Icons.wifi_off,
  ),
  CompetitorFailure.badResponse => (
    'Something went wrong',
    'The map data server sent a reply we couldn’t read'
        '${statusCode == null ? '' : ' (code $statusCode)'}. Try again.',
    Icons.error_outline,
  ),
};

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.failure,
    required this.statusCode,
    required this.onRetry,
    required this.onSample,
  });

  final CompetitorFailure failure;
  final int? statusCode;
  final VoidCallback onRetry;
  final VoidCallback onSample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, message, icon) = describeOverpassFailure(failure, statusCode);
    return _Card(
      color: context.palette.dangerContainer,
      borderColor: context.palette.dangerBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Nothing is shown, because no results came back.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.tonalIcon(
                style: _compactButton,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
              OutlinedButton.icon(
                style: _compactButton,
                onPressed: onSample,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Use sample demo data'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.result, required this.onRefresh});

  final CompetitorResult result;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = result.query;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResultHeader(
            title: '0 businesses found',
            result: result,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.palette.accentContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.search_off, color: context.palette.brand),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CompetitorResults.emptyMessage,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'OpenStreetMap lists no ${query.category.label.toLowerCase()} '
                      'businesses within ${query.radius.label}. Some may '
                      'exist but not be on the map yet. Try a larger radius '
                      'or another spot.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.state,
    required this.showAll,
    required this.onShowAll,
    required this.onOpen,
    required this.onRefresh,
    required this.onLeaveSample,
  });

  final CompetitorSearchState state;
  final bool showAll;
  final VoidCallback onShowAll;
  final ValueChanged<NearbyBusiness> onOpen;
  final VoidCallback onRefresh;
  final VoidCallback onLeaveSample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = state.result!;
    final isSample = result.source == DataSource.sample;
    final businesses = result.businesses;
    final visible =
        showAll || businesses.length <= CompetitorResults.initialRows
        ? businesses
        : businesses.take(CompetitorResults.initialRows).toList();
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.palette.textSecondary,
    );
    final unnamed = businesses.where((b) => b.name == null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSample) ...[
          const SampleBanner(),
          const SizedBox(height: AppSpacing.md),
        ],
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResultHeader(
                title: isSample
                    ? '${result.count} sample businesses'
                    : '${result.count} '
                          '${result.count == 1 ? 'business' : 'businesses'} '
                          'found',
                result: result,
                onRefresh: isSample ? null : onRefresh,
              ),
              if (state.notice != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(state.notice!, style: muted),
              ],
              if (unnamed > 0 && !isSample) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$unnamed ${unnamed == 1 ? 'has' : 'have'} no name in '
                  'OpenStreetMap.',
                  style: muted,
                ),
              ],
              if (result.skippedCount > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${result.skippedCount} returned '
                  '${result.skippedCount == 1 ? 'place was' : 'places were'} '
                  'skipped for missing coordinates.',
                  style: muted,
                ),
              ],
              if (result.possiblyTruncated) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'The server returned its maximum number of results; some '
                  'may be missing. Try a smaller radius.',
                  style: muted,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final (index, business) in visible.indexed)
          _BusinessTile(
            index: index + 1,
            business: business,
            category: result.query.category,
            selected: business.key == state.selectedKey,
            onTap: () => onOpen(business),
          ),
        if (visible.length < businesses.length)
          TextButton(
            onPressed: onShowAll,
            child: Text('Show all ${businesses.length}'),
          ),
        if (isSample) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onLeaveSample,
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Try the live search again'),
          ),
        ],
      ],
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.title,
    required this.result,
    required this.onRefresh,
  });

  final String title;
  final CompetitorResult result;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = result.query;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  SourceBadge(source: result.source),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${query.category.label} · within ${query.radius.label} · on '
                'OpenStreetMap',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              SourceLine(result: result),
            ],
          ),
        ),
        if (onRefresh != null)
          IconButton(
            tooltip: 'Search again',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            color: context.palette.brand,
          ),
      ],
    );
  }
}

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({
    required this.index,
    required this.business,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final NearbyBusiness business;
  final BusinessCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.palette.textSecondary,
    );
    final subtitle = business.details['Address'] ?? business.details['Brand'];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? context.palette.accentWash : context.palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected ? context.palette.brand : context.palette.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  BusinessThumbnail(business: business, category: category),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$index. ${business.displayName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontStyle: business.name == null
                                ? FontStyle.italic
                                : null,
                            color: business.name == null
                                ? context.palette.textSecondary
                                : null,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.palette.accentWash,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      formatDistance(business.distanceMeters),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: context.palette.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: context.palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverageNote extends StatelessWidget {
  const _CoverageNote({required this.sample});

  /// Under sample records the OSM attribution would wrongly suggest the
  /// list came from OpenStreetMap, so say where live data comes from.
  final bool sample;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 18,
          color: context.palette.textSecondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sample)
                Text(CompetitorResults.sampleNote, style: style)
              else ...[
                Text(CompetitorResults.coverageNote, style: style),
                const SizedBox(height: AppSpacing.xs),
                Text(CompetitorResults.attribution, style: style),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color, this.borderColor});

  final Widget child;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color ?? context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor ?? context.palette.border),
        boxShadow: context.palette.cardShadow,
      ),
      child: child,
    );
  }
}

final _compactButton = ButtonStyle(
  minimumSize: WidgetStateProperty.all(const Size(0, 48)),
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/geo.dart';
import '../domain/competitors.dart';
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

  static const emptyMessage = 'No mapped records found within this radius.';
  static const coverageNote =
      'Only businesses mapped in OpenStreetMap appear. Coverage is '
      'incomplete and can be out of date, so this is not a full list of '
      'businesses or a measure of their activity.';
  static const attribution =
      'Business data © OpenStreetMap contributors (ODbL), via the Overpass '
      'API.';

  static const sampleNote =
      'The records above are fictional sample data. Live searches use '
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
          Text('Searching OpenStreetMap…', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          const LinearProgressIndicator(
            semanticsLabel: 'Searching OpenStreetMap',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Querying the public Overpass API. Shared servers can take up to '
            'a minute to answer.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: BrandColors.inkMuted,
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
    'Search timed out',
    'The Overpass server took too long to answer. Try again in a moment.',
    Icons.hourglass_empty,
  ),
  CompetitorFailure.rateLimited => (
    'Too many requests (HTTP 429)',
    'The public Overpass server is limiting requests. Wait a minute '
        'before retrying.',
    Icons.front_hand_outlined,
  ),
  CompetitorFailure.serverBusy => (
    'Overpass server busy${statusCode == null ? '' : ' (HTTP $statusCode)'}',
    'The server could not run the search right now. Try again shortly.',
    Icons.dns_outlined,
  ),
  CompetitorFailure.network => (
    'No connection',
    'Could not reach the Overpass server. Check the internet connection '
        'and try again.',
    Icons.wifi_off,
  ),
  CompetitorFailure.badResponse => (
    'Unexpected response${statusCode == null ? '' : ' (HTTP $statusCode)'}',
    'The server answered with something PWESTADO could not read.',
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
      color: const Color(0xFFFFF4F2),
      borderColor: const Color(0xFFF1C9C2),
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
            'No competitor records are shown because none were retrieved.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: BrandColors.inkMuted,
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
            title: '0 mapped records',
            result: result,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.search_off, color: BrandColors.emerald700),
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
                      'OpenStreetMap has no ${query.category.osmTag} records '
                      'within ${query.radius.label} of this site. Businesses '
                      'may still exist here but not be mapped yet. Try a '
                      'larger radius or another site.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BrandColors.inkMuted,
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
      color: BrandColors.inkMuted,
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
                    ? '${result.count} sample records'
                    : '${result.count} mapped '
                          '${result.count == 1 ? 'record' : 'records'}',
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
                  '${result.skippedCount == 1 ? 'record was' : 'records were'} '
                  'skipped for missing coordinates.',
                  style: muted,
                ),
              ],
              if (result.possiblyTruncated) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'The server returned the maximum number of records; some '
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
                '${query.category.label} (${query.category.osmTag}) within '
                '${query.radius.label}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              SourceLine(result: result),
            ],
          ),
        ),
        if (onRefresh != null)
          IconButton(
            tooltip: 'Refresh from OpenStreetMap',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            color: BrandColors.emerald700,
          ),
      ],
    );
  }
}

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({
    required this.index,
    required this.business,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final NearbyBusiness business;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: BrandColors.inkMuted,
    );
    final subtitle = business.details['Address'] ?? business.details['Brand'];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? BrandColors.mintSoft : BrandColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(
            color: selected ? BrandColors.emerald500 : BrandColors.outline,
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
                  const CompetitorDot(),
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
                                ? BrandColors.inkMuted
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
                  Text(
                    formatDistance(business.distanceMeters),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: BrandColors.emerald700,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: BrandColors.inkMuted),
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
    ).textTheme.bodySmall?.copyWith(color: BrandColors.inkMuted);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: BrandColors.inkMuted),
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
  const _Card({
    required this.child,
    this.color = BrandColors.offWhite,
    this.borderColor = BrandColors.outline,
  });

  final Widget child;
  final Color color;
  final Color borderColor;

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
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

final _compactButton = ButtonStyle(
  minimumSize: WidgetStateProperty.all(const Size(0, 48)),
);

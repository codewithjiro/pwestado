import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/elapsed_wait.dart';
import '../../../core/models/selected_site.dart';
import '../../../core/utils/geo.dart';
import '../../analysis/domain/site_analysis.dart';
import '../../analysis/domain/suitability_scoring.dart';
import '../../discovery/domain/competitors.dart';
import '../../discovery/presentation/competitor_results.dart';
import '../../discovery/presentation/source_labels.dart';
import '../../explore/presentation/widgets/compare_pin_image.dart';
import '../../explore/state/explore_controller.dart';
import '../domain/site_comparison.dart';
import '../state/comparison_controller.dart';

/// Site A / Site B comparison card: two independent slots, their side by
/// side evidence, and a verdict that ranks scores only when both are
/// comparable.
class ComparisonSection extends ConsumerWidget {
  const ComparisonSection({super.key});

  static const title = 'Compare two sites';
  static const useCurrentPin = 'Use current pin';
  static const moveToCurrentPin = 'Move to current pin';
  static const analyzeBoth = 'Analyze both sites';
  static const notComparable = 'Not comparable yet';
  static const similarScores = 'Scores are similar';
  static const disclaimer =
      'A higher heuristic score is not an objectively better site. It does '
      'not predict sales, customer demand, foot traffic, profit, or business '
      'success.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(comparisonControllerProvider);
    final controller = ref.read(comparisonControllerProvider.notifier);
    final explore = ref.watch(exploreControllerProvider);
    final comparison = ref.watch(siteComparisonProvider);
    final loadingSlot = slots.loadingSlot;

    bool needsAnalysis(SlotState s) {
      final site = s.site;
      if (site == null || s.isLoading) return false;
      final query = CompetitorQuery.forSite(
        site,
        explore.category,
        explore.radius,
      );
      return s.analysis?.competitors.query != query;
    }

    final bothAssigned = slots.a.site != null && slots.b.site != null;
    final canAnalyzeBoth =
        bothAssigned &&
        loadingSlot == null &&
        CompareSlot.values.any((s) => needsAnalysis(slots[s]));

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.compare_arrows_rounded,
                  color: BrandColors.emerald700,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(title, style: _title(context))),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Both sites are analyzed with the same settings: '
              '${explore.category.label} · ${explore.radius.label}. Each site '
              'keeps its own pin and evidence.',
              style: _muted(context),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final slot in CompareSlot.values) ...[
              _SlotTile(
                slot: slot,
                state: slots[slot],
                currentSite: explore.site,
                needsAnalysis: needsAnalysis(slots[slot]),
                otherLoading: loadingSlot == slot.other,
                controller: controller,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (!slots.hasAnySite || !bothAssigned)
              Text(
                slots.a.site == null
                    ? 'Long-press a spot on the map, then tap '
                          '"$useCurrentPin" for Site A. Pick a second spot '
                          'for Site B.'
                    : 'Long-press a different spot on the map, then tap '
                          '"$useCurrentPin" for Site B.',
                style: _muted(context),
              ),
            if (canAnalyzeBoth) ...[
              const SizedBox(height: AppSpacing.xs),
              FilledButton.tonalIcon(
                onPressed: controller.analyzeAll,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text(analyzeBoth),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Runs one site at a time and reuses saved results when '
                'possible. Each new site can take up to a minute.',
                style: _muted(context),
                textAlign: TextAlign.center,
              ),
            ],
            if (bothAssigned) ...[
              const SizedBox(height: AppSpacing.md),
              ComparisonTable(slots: slots, comparison: comparison),
              const SizedBox(height: AppSpacing.md),
              _Verdict(slots: slots, comparison: comparison),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.state,
    required this.currentSite,
    required this.needsAnalysis,
    required this.otherLoading,
    required this.controller,
  });

  final CompareSlot slot;
  final SlotState state;
  final SelectedSite? currentSite;
  final bool needsAnalysis;
  final bool otherLoading;
  final ComparisonController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final site = state.site;
    final analysis = state.analysis;
    final current = currentSite;
    final canTakePin = current != null && current.id != site?.id;

    final List<Widget> details;
    switch (state.status) {
      case SlotStatus.empty:
        details = [Text('No site chosen.', style: _muted(context))];
      case SlotStatus.pending:
        details = [Text('Not analyzed yet.', style: _muted(context))];
      case SlotStatus.loading:
        details = [
          Text(
            'Fetching OpenStreetMap evidence… can take up to a minute.',
            style: _muted(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(semanticsLabel: 'Analyzing ${slot.title}'),
          const SizedBox(height: AppSpacing.xs),
          const ElapsedWait(),
        ];
      case SlotStatus.failed:
        final (title, message, _) = describeOverpassFailure(
          state.failure!,
          state.statusCode,
        );
        details = [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          Text(message, style: _muted(context)),
        ];
      case SlotStatus.ready:
        details = [
          Text(
            '${settingsLabel(analysis!.competitors.query)} · '
            '${_scoreText(analysis.score.total)}',
            style: theme.textTheme.labelLarge,
          ),
          if (needsAnalysis)
            Text(
              'Analyzed with different settings; re-analyze to compare.',
              style: _muted(context),
            ),
          if (state.reused)
            Text(
              'Reused from the analysis above. No new request.',
              style: _muted(context),
            ),
        ];
    }

    final actions = <Widget>[
      if (state.isLoading)
        TextButton(
          style: _compact,
          onPressed: () => controller.cancel(slot),
          child: const Text('Cancel'),
        )
      else ...[
        if (canTakePin)
          OutlinedButton.icon(
            style: _compact,
            onPressed: () => controller.assignCurrentSite(slot),
            icon: const Icon(Icons.push_pin_outlined, size: 18),
            label: Text(
              site == null
                  ? ComparisonSection.useCurrentPin
                  : ComparisonSection.moveToCurrentPin,
            ),
          ),
        if (needsAnalysis)
          FilledButton.tonal(
            style: _compact,
            onPressed: otherLoading ? null : () => controller.analyze(slot),
            child: Text(
              state.status == SlotStatus.failed
                  ? 'Try again'
                  : 'Analyze ${slot.title}',
            ),
          ),
        if (state.status == SlotStatus.ready &&
            !needsAnalysis &&
            !analysis!.isSample)
          TextButton.icon(
            style: _compact,
            onPressed: otherLoading
                ? null
                : () => controller.analyze(slot, forceRefresh: true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
        if (state.status == SlotStatus.failed)
          OutlinedButton.icon(
            style: _compact,
            onPressed: () => controller.useSample(slot),
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('Use sample demo data'),
          ),
        if (site != null)
          TextButton(
            style: _compact,
            onPressed: () => controller.clear(slot),
            child: Text('Clear ${slot.letter}'),
          ),
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: site == null ? BrandColors.offWhite : BrandColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: BrandColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SlotBadge(slot: slot),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(slot.title, style: theme.textTheme.titleSmall),
                    if (analysis != null)
                      SourceBadge(source: analysis.competitors.source),
                  ],
                ),
                if (site != null)
                  Text(
                    '${site.coordinatesLabel} · ${site.displayLabel}',
                    style: _muted(context),
                  ),
                const SizedBox(height: 2),
                ...details,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lettered disc matching the Site A / Site B map pins.
class SlotBadge extends StatelessWidget {
  const SlotBadge({super.key, required this.slot, this.size = 32});

  final CompareSlot slot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = compareSlotColors(slot);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: BrandColors.emerald900, width: 1.5),
      ),
      child: Text(
        slot.letter,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Side-by-side evidence for Site A and Site B.
class ComparisonTable extends StatelessWidget {
  const ComparisonTable({
    super.key,
    required this.slots,
    required this.comparison,
  });

  final ComparisonState slots;
  final SiteComparison comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.labelMedium?.copyWith(
      color: BrandColors.inkMuted,
    );
    final value = theme.textTheme.bodySmall?.copyWith(color: BrandColors.ink);

    TableRow row(String name, String Function(SlotState s) cell) => TableRow(
      children: [
        _Cell(Text(name, style: label)),
        for (final slot in CompareSlot.values)
          _Cell(Text(cell(slots[slot]), style: value)),
      ],
    );

    String ready(SlotState s, String Function(SiteAnalysis a) f) {
      final analysis = s.analysis;
      if (analysis != null) return f(analysis);
      return switch (s.status) {
        SlotStatus.loading => 'Loading…',
        SlotStatus.failed => 'Search failed',
        _ => 'Not analyzed',
      };
    }

    final higher = comparison.higher;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: BrandColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(0.9),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        border: const TableBorder(
          horizontalInside: BorderSide(color: BrandColors.outline),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: [
          TableRow(
            decoration: const BoxDecoration(color: BrandColors.offWhite),
            children: [
              const _Cell(SizedBox.shrink()),
              for (final slot in CompareSlot.values)
                _Cell(
                  Row(
                    children: [
                      SlotBadge(slot: slot, size: 24),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          slot.title,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          row('Location', (s) => s.site?.coordinatesLabel ?? '—'),
          row(
            'Settings',
            (s) => ready(s, (a) => settingsLabel(a.competitors.query)),
          ),
          row(
            'Competitors mapped',
            (s) => ready(s, (a) {
              final near = a.competitors.businesses
                  .where(
                    (b) =>
                        b.distanceMeters <=
                        SuitabilityRules.competitorNearMeters,
                  )
                  .length;
              return '${a.competitors.count}'
                  '${a.competitors.possiblyTruncated ? '+' : ''} '
                  '($near within ${SuitabilityRules.competitorNearMeters} m)';
            }),
          ),
          row(
            'Complementary mapped',
            (s) => ready(s, (a) {
              final c = a.context?.complementary;
              return c == null ? 'No data' : '${c.count}';
            }),
          ),
          row('Road proxy', (s) => ready(s, (a) => _roadText(a))),
          TableRow(
            children: [
              _Cell(Text('Heuristic score', style: label)),
              for (final slot in CompareSlot.values)
                _ScoreCell(
                  text: ready(slots[slot], (a) => _scoreText(a.score.total)),
                  highlighted: higher == slot,
                ),
            ],
          ),
          TableRow(
            children: [
              _Cell(Text('Data source', style: label)),
              for (final slot in CompareSlot.values)
                _Cell(_SourceCell(state: slots[slot])),
            ],
          ),
          row(
            'Retrieved',
            (s) => ready(s, (a) {
              final competitors = formatFetchedAt(
                context,
                a.competitors.fetchedAt,
              );
              final siteContext = a.context;
              if (siteContext == null) return 'Competitors $competitors';
              return 'Competitors $competitors\nContext '
                  '${formatFetchedAt(context, siteContext.fetchedAt)}';
            }),
          ),
        ],
      ),
    );
  }

  static String _roadText(SiteAnalysis a) {
    final roads = a.context?.roads;
    if (roads == null) return 'No data';
    final nearest = roads.nearestRoadMeters;
    if (roads.roadCount == 0 || nearest == null) {
      return 'None mapped within ${SuitabilityRules.roadSearchMeters} m';
    }
    final major = roads.nearestMajorRoadMeters;
    return 'Road ${formatDistance(nearest)}'
        '${major == null ? '' : '; major ${formatDistance(major)}'}';
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.sm,
    ),
    child: child,
  );
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({required this.text, required this.highlighted});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: highlighted ? BrandColors.mintSoft : null,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              color: BrandColors.emerald900,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (highlighted)
            Text(
              'Higher heuristic score',
              style: theme.textTheme.labelSmall?.copyWith(
                color: BrandColors.emerald700,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceCell extends StatelessWidget {
  const _SourceCell({required this.state});

  final SlotState state;

  @override
  Widget build(BuildContext context) {
    final analysis = state.analysis;
    if (analysis == null) return Text('—', style: _muted(context));
    final siteContext = analysis.context;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SourceText('Competitors', analysis.competitors.source),
        const SizedBox(height: AppSpacing.xs),
        if (siteContext != null)
          _SourceText('Context', siteContext.source)
        else
          Text('Context: request failed', style: _muted(context)),
      ],
    );
  }
}

/// Wrapping text form of [SourceBadge] that fits a narrow table column.
class _SourceText extends StatelessWidget {
  const _SourceText(this.label, this.source);

  final String label;
  final DataSource source;

  @override
  Widget build(BuildContext context) {
    final sample = source == DataSource.sample;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: sample ? SampleBanner.foreground : BrandColors.ink,
      fontWeight: sample ? FontWeight.w800 : FontWeight.w600,
    );
    final text = Text(
      '$label: ${sample ? SampleBanner.title : source.label}',
      style: style,
    );
    if (!sample) return text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: SampleBanner.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: text,
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.slots, required this.comparison});

  final ComparisonState slots;
  final SiteComparison comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final higher = comparison.higher;
    final anyReal = CompareSlot.values.any(
      (s) => slots[s].analysis != null && !slots[s].analysis!.isSample,
    );

    final Widget headline;
    if (comparison.blockedBy(ComparisonBlockerKind.missingAnalysis) &&
        comparison.blockers.length == 1) {
      headline = _Note(
        icon: Icons.hourglass_empty,
        title: 'Waiting for both analyses',
        lines: [comparison.blockers.single.message],
      );
    } else if (!comparison.isComparable) {
      headline = _Note(
        icon: Icons.block,
        title: ComparisonSection.notComparable,
        lines: [for (final b in comparison.blockers) b.message],
        background: const Color(0xFFFFF4F2),
        border: const Color(0xFFF1C9C2),
        iconColor: theme.colorScheme.error,
      );
    } else if (higher == null) {
      headline = _Note(
        icon: Icons.drag_handle_rounded,
        title: ComparisonSection.similarScores,
        lines: [
          '${_scoreText(slots.a.analysis!.score.total)} vs '
              '${_scoreText(slots.b.analysis!.score.total)}: within '
              '${ComparisonRules.similarScorePoints.round()} points, which '
              'this heuristic cannot meaningfully separate.',
        ],
      );
    } else {
      final winner = slots[higher].analysis!;
      final loser = slots[higher.other].analysis!;
      headline = _Note(
        icon: Icons.trending_up_rounded,
        title: '${higher.title} has the higher heuristic score',
        lines: [
          '${_scoreText(winner.score.total)} vs '
              '${_scoreText(loser.score.total)} '
              '(+${comparison.difference!.abs().toStringAsFixed(1)} points) '
              'for ${settingsLabel(winner.competitors.query)}.',
        ],
        background: BrandColors.mintSoft,
        border: BrandColors.mint,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (comparison.sampleOnly) ...[
          const SampleBanner(),
          const SizedBox(height: AppSpacing.sm),
        ],
        headline,
        for (final warning in comparison.warnings) ...[
          const SizedBox(height: AppSpacing.sm),
          _Note(
            icon: Icons.warning_amber_rounded,
            lines: [warning],
            background: SampleBanner.background,
            border: const Color(0xFFE2B93B),
            iconColor: SampleBanner.foreground,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(ComparisonSection.disclaimer, style: _muted(context)),
        if (anyReal) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(CompetitorResults.attribution, style: _muted(context)),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.lines,
    this.title,
    this.background = BrandColors.offWhite,
    this.border = BrandColors.outline,
    this.iconColor = BrandColors.emerald700,
  });

  final IconData icon;
  final String? title;
  final List<String> lines;
  final Color background;
  final Color border;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  Text(title!, style: theme.textTheme.titleSmall),
                for (final line in lines)
                  Text(line, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BrandColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: BrandColors.mint, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}

/// "64 / 100" or "Insufficient data".
String _scoreText(double? total) =>
    total == null ? 'Insufficient data' : '${total.round()} / 100';

TextStyle? _title(BuildContext context) =>
    Theme.of(context).textTheme.titleMedium;

TextStyle? _muted(BuildContext context) => Theme.of(
  context,
).textTheme.bodySmall?.copyWith(color: BrandColors.inkMuted);

final _compact = ButtonStyle(
  minimumSize: WidgetStateProperty.all(const Size(0, 48)),
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/elapsed_wait.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../../core/models/selected_site.dart';
import '../../../core/utils/geo.dart';
import '../../ai/data/ai_payload.dart';
import '../../ai/presentation/ai_insights_card.dart';
import '../../analysis/domain/site_analysis.dart';
import '../../analysis/domain/suitability_scoring.dart';
import '../../analysis/presentation/site_analysis_section.dart';
import '../../discovery/domain/competitors.dart';
import '../../discovery/presentation/competitor_results.dart';
import '../../discovery/presentation/source_labels.dart';
import '../../explore/presentation/widgets/compare_pin_image.dart';
import '../../explore/state/explore_controller.dart';
import '../../places/presentation/site_place_label.dart';
import '../../places/state/place_providers.dart';
import '../../saved/presentation/saved_widgets.dart';
import '../../saved/state/saved_analyses_controller.dart';
import '../domain/site_comparison.dart';
import '../state/comparison_controller.dart';

/// First / second location comparison card: two independent slots, one
/// clear next step, their side by side evidence, and a verdict that ranks
/// scores only when both are comparable.
class ComparisonSection extends ConsumerWidget {
  const ComparisonSection({super.key});

  static const title = 'Compare two locations';
  static const compareLabel = 'Compare locations';
  static const compareAgainLabel = 'Compare again';
  static const notComparable = 'Can’t compare these yet';
  static const similarScores = 'The two locations score about the same';
  static const disclaimer =
      'A higher score doesn’t guarantee a better location. It doesn’t '
      'predict sales, customer demand, foot traffic, profit or business '
      'success.';

  /// "Use this as the first location" / "... second location".
  static String useAs(CompareSlot slot) =>
      'Use this as the ${slot.title.toLowerCase()}';

  /// "Choose the first location" / "... second location".
  static String choose(CompareSlot slot) =>
      'Choose the ${slot.title.toLowerCase()}';

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
    // A failed slot has its own "Try again"; the main button is for slots
    // that were never checked or were checked with older settings.
    final canCompare =
        bothAssigned &&
        loadingSlot == null &&
        CompareSlot.values.any(
          (s) =>
              needsAnalysis(slots[s]) && slots[s].status != SlotStatus.failed,
        );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.compare_arrows_rounded,
              title: title,
              subtitle: 'Both use the same business type and distance',
            ),
            const SizedBox(height: AppSpacing.md),
            _SharedSettings(
              category: explore.category.label,
              radius: explore.radius.label,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final slot in CompareSlot.values) ...[
              _SlotTile(
                slot: slot,
                state: slots[slot],
                otherSite: slots[slot.other].site,
                currentSite: explore.site,
                needsAnalysis: needsAnalysis(slots[slot]),
                otherLoading: loadingSlot == slot.other,
                controller: controller,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _NextStep(
              slots: slots,
              currentSite: explore.site,
              canCompare: canCompare,
              comparedBefore: CompareSlot.values.any(
                (s) => slots[s].analysis != null,
              ),
              controller: controller,
            ),
            if (bothAssigned) ...[
              const SizedBox(height: AppSpacing.md),
              _Verdict(slots: slots, comparison: comparison),
              const SizedBox(height: AppSpacing.md),
              ComparisonTable(slots: slots, comparison: comparison),
              const SizedBox(height: AppSpacing.sm),
              Text(disclaimer, style: _muted(context)),
              if (CompareSlot.values.any(
                (s) =>
                    slots[s].analysis != null && !slots[s].analysis!.isSample,
              )) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(CompetitorResults.attribution, style: _muted(context)),
              ],
            ],
            if (slots.a.analysis != null && slots.b.analysis != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AiInsightsCard(
                compare: true,
                payload: comparison.blockers.isEmpty
                    ? AiPayload.comparison(
                        a: slots.a.analysis!,
                        b: slots.b.analysis!,
                        areaA: _area(ref, slots.a.site),
                        areaB: _area(ref, slots.b.site),
                        verdict: comparison,
                      )
                    : null,
                unavailableMessage:
                    'AI can compare once both locations have a complete score '
                    'with the same search settings.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The business type and distance both locations are checked with.
class _SharedSettings extends StatelessWidget {
  const _SharedSettings({required this.category, required this.radius});

  final String category;
  final String radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$category · within $radius', style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            'Both locations are checked for this business type, counting '
            'what is on the map within $radius around each spot. To change '
            'these, go to MAPA.',
            style: _muted(context),
          ),
        ],
      ),
    );
  }
}

/// The one main action for the comparison's current state, with its
/// reason when something is still missing.
class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.slots,
    required this.currentSite,
    required this.canCompare,
    required this.comparedBefore,
    required this.controller,
  });

  final ComparisonState slots;
  final SelectedSite? currentSite;
  final bool canCompare;
  final bool comparedBefore;
  final ComparisonController controller;

  @override
  Widget build(BuildContext context) {
    final current = currentSite;
    final empty = slots.a.site == null
        ? CompareSlot.a
        : slots.b.site == null
        ? CompareSlot.b
        : null;

    if (empty != null) {
      // Without any map location the page's guidance card explains the
      // first step, so don't repeat it here.
      if (current == null && !slots.hasAnySite) return const SizedBox.shrink();
      final otherSite = slots[empty.other].site;
      final usable = current != null && current.id != otherSite?.id;
      if (usable) {
        return _ActionWithNote(
          button: FilledButton.icon(
            onPressed: () => controller.assignCurrentSite(empty),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(ComparisonSection.useAs(empty)),
          ),
          // Wraps instead of overflowing on narrow screens and large text.
          note: Wrap(
            spacing: AppSpacing.xs,
            children: [
              Text('Map location:', style: _muted(context)),
              PlaceTitleText(site: current, style: _muted(context)),
            ],
          ),
        );
      }
      return _ActionWithNote(
        button: FilledButton.tonalIcon(
          onPressed: () => context.go(AppRoutes.explore),
          icon: const Icon(Icons.map_outlined),
          label: Text(ComparisonSection.choose(empty)),
        ),
        note: Text(
          otherSite != null
              ? 'On MAPA, choose a different spot from the '
                    '${empty.other.title.toLowerCase()} (search, use your '
                    'location, or pick on the map), then come back here.'
              : 'On MAPA, search for a place, use your location, or pick a '
                    'spot on the map, then come back here.',
          style: _muted(context),
        ),
      );
    }

    if (!canCompare) return const SizedBox.shrink();
    return _ActionWithNote(
      button: FilledButton.icon(
        onPressed: controller.analyzeAll,
        icon: const Icon(Icons.compare_arrows_rounded),
        label: Text(
          comparedBefore
              ? ComparisonSection.compareAgainLabel
              : ComparisonSection.compareLabel,
        ),
      ),
      note: Text(
        'Checks one location at a time and reuses results you already '
        'have. Each new check can take up to a minute.',
        style: _muted(context),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ActionWithNote extends StatelessWidget {
  const _ActionWithNote({required this.button, required this.note});

  final Widget button;
  final Widget note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          button,
          const SizedBox(height: AppSpacing.xs),
          note,
        ],
      ),
    );
  }
}

/// General area (town/province) for the AI request, if already looked up.
String? _area(WidgetRef ref, SelectedSite? site) => site == null
    ? null
    : ref.watch(placeLabelProvider(pointOf(site))).value?.subtitle;

class _SlotTile extends ConsumerWidget {
  const _SlotTile({
    required this.slot,
    required this.state,
    required this.otherSite,
    required this.currentSite,
    required this.needsAnalysis,
    required this.otherLoading,
    required this.controller,
  });

  final CompareSlot slot;
  final SlotState state;
  final SelectedSite? otherSite;
  final SelectedSite? currentSite;
  final bool needsAnalysis;
  final bool otherLoading;
  final ComparisonController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final site = state.site;
    final analysis = state.analysis;
    final current = currentSite;
    final savedAt = state.savedAt;
    final alreadySaved =
        analysis != null &&
        ref.watch(
          savedAnalysesControllerProvider.select(
            (s) => s.savedIds.containsKey(analysis),
          ),
        );
    final saving =
        analysis != null &&
        ref.watch(
          savedAnalysesControllerProvider.select((s) => s.isSaving(analysis)),
        );
    // Replacing is offered only with a map location that is in neither
    // slot; empty slots are filled through the main next-step button.
    final canReplace =
        site != null &&
        current != null &&
        current.id != site.id &&
        current.id != otherSite?.id;

    final List<Widget> details;
    switch (state.status) {
      case SlotStatus.empty:
        details = [Text('Not chosen yet.', style: _muted(context))];
      case SlotStatus.pending:
        details = [Text('Chosen. Not checked yet.', style: _muted(context))];
      case SlotStatus.loading:
        details = [
          Text(
            'Checking the map… this can take up to a minute.',
            style: _muted(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            semanticsLabel: 'Checking ${slot.inSentence}',
          ),
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
          Text(
            'Try again, or use sample demo data to see how the comparison '
            'works.',
            style: _muted(context),
          ),
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
              'Checked with different settings. Compare again to update it.',
              style: _muted(context),
            ),
          if (state.reused)
            Text(
              'Same result as your ANALYZE tab, so no extra waiting.',
              style: _muted(context),
            ),
          if (savedAt != null)
            Text(
              'Saved on ${formatSavedDate(context, savedAt)}. Shows information '
              'from then, not today.',
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
        if (state.status == SlotStatus.failed)
          FilledButton.tonal(
            style: _compact,
            onPressed: otherLoading ? null : () => controller.analyze(slot),
            child: const Text('Try again'),
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
        if (state.status == SlotStatus.ready &&
            !needsAnalysis &&
            !state.isSaved &&
            !state.reused &&
            !alreadySaved)
          TextButton.icon(
            style: _compact,
            onPressed: saving
                ? null
                : () => saveAnalysis(context, ref, site!, analysis!),
            icon: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bookmark_add_outlined, size: 18),
            label: Text(saving ? 'Saving…' : 'Save'),
          ),
        if (state.status == SlotStatus.failed)
          OutlinedButton.icon(
            style: _compact,
            onPressed: () => controller.useSample(slot),
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('Use sample demo data'),
          ),
        if (canReplace)
          TextButton.icon(
            style: _compact,
            onPressed: () => controller.assignCurrentSite(slot),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Replace with map location'),
          ),
        if (site != null)
          TextButton(
            style: _compact,
            onPressed: () => controller.clear(slot),
            child: Text('Remove', semanticsLabel: 'Remove ${slot.inSentence}'),
          ),
      ],
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: site == null
            ? context.palette.surfaceMuted
            : context.palette.accentWash,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: site == null
              ? context.palette.borderStrong
              : context.palette.accentContainer,
        ),
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
                    // With a place the name leads and this is a small
                    // label; without one it is the tile's title.
                    Text(
                      site == null ? slot.title : slot.title.toUpperCase(),
                      style: site == null
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.labelSmall?.copyWith(
                              color: context.palette.brand,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                    ),
                    if (analysis != null)
                      SourceBadge(source: analysis.competitors.source),
                    if (state.isSaved) const HistoricalPill(),
                  ],
                ),
                if (site != null)
                  SitePlaceLabel(
                    site: site,
                    titleStyle: theme.textTheme.titleSmall,
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

/// Numbered disc matching the first / second location map pins.
class SlotBadge extends StatelessWidget {
  const SlotBadge({super.key, required this.slot, this.size = 32});

  final CompareSlot slot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = compareSlotColors(slot);
    // Decorative: the slot's title is always shown next to it.
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: context.palette.heading, width: 1.5),
          boxShadow: context.palette.cardShadow,
        ),
        child: Text(
          slot.badge,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Side-by-side evidence for the first and second location.
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
      color: context.palette.textSecondary,
    );
    final value = theme.textTheme.bodySmall?.copyWith(
      color: context.palette.textPrimary,
    );

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
        SlotStatus.loading => 'Checking…',
        SlotStatus.failed => 'Search failed',
        _ => 'Not checked yet',
      };
    }

    final higher = comparison.higher;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.palette.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(0.9),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        border: TableBorder(
          horizontalInside: BorderSide(color: context.palette.border),
          verticalInside: BorderSide(color: context.palette.border),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: [
          TableRow(
            decoration: BoxDecoration(color: context.palette.accentWash),
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
          TableRow(
            children: [
              _Cell(Text('Location', style: label)),
              for (final slot in CompareSlot.values)
                _Cell(
                  slots[slot].site == null
                      ? Text('—', style: value)
                      : PlaceTitleText(site: slots[slot].site!, style: value),
                ),
            ],
          ),
          row(
            'Checked for',
            (s) => ready(s, (a) => settingsLabel(a.competitors.query)),
          ),
          row(
            'Similar businesses on the map',
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
            'Helpful places on the map',
            (s) => ready(s, (a) {
              final c = a.context?.complementary;
              return c == null ? 'No data' : '${c.count}';
            }),
          ),
          row('Nearest mapped road', (s) => ready(s, (a) => _roadText(a))),
          TableRow(
            children: [
              _Cell(Text('Suitability score', style: label)),
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
            'Map data from',
            (s) => ready(s, (a) {
              final competitors = formatFetchedAt(
                context,
                a.competitors.fetchedAt,
              );
              final siteContext = a.context;
              if (siteContext == null) return 'Businesses $competitors';
              return 'Businesses $competitors\nPlaces & roads '
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
        '${major == null ? '' : '; major road ${formatDistance(major)}'}';
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
      color: highlighted ? context.palette.accentContainer : null,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              color: context.palette.heading,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (highlighted)
            Text(
              'Higher score',
              style: theme.textTheme.labelSmall?.copyWith(
                color: context.palette.brand,
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
        _SourceText('Businesses', analysis.competitors.source),
        const SizedBox(height: AppSpacing.xs),
        if (siteContext != null)
          _SourceText('Places & roads', siteContext.source)
        else
          Text('Places & roads: couldn’t load', style: _muted(context)),
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
      color: sample ? context.palette.sample : context.palette.textPrimary,
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
        color: context.palette.sampleContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: text,
    );
  }
}

/// The comparison in plain language: which location scores higher and
/// why, or what still blocks a fair comparison.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.slots, required this.comparison});

  final ComparisonState slots;
  final SiteComparison comparison;

  @override
  Widget build(BuildContext context) {
    final higher = comparison.higher;

    final Widget headline;
    if (comparison.blockedBy(ComparisonBlockerKind.missingAnalysis) &&
        comparison.blockers.length == 1) {
      headline = InfoNote(
        icon: Icons.hourglass_empty,
        title: 'Waiting for both results',
        lines: [comparison.blockers.single.message],
      );
    } else if (!comparison.isComparable) {
      headline = InfoNote(
        icon: Icons.block,
        title: ComparisonSection.notComparable,
        lines: [for (final b in comparison.blockers) b.message],
        tone: NoteTone.danger,
      );
    } else if (higher == null) {
      final a = slots.a.analysis!;
      final b = slots.b.analysis!;
      headline = InfoNote(
        icon: Icons.drag_handle_rounded,
        title: ComparisonSection.similarScores,
        lines: [
          '${_scoreText(a.score.total)} vs ${_scoreText(b.score.total)}: '
              'less than ${ComparisonRules.similarScorePoints.round()} points '
              'apart, which this simple score can’t meaningfully separate.',
          ..._reasonLines(
            criterionDifferences(a, b),
            'Where the first location differs:',
          ),
        ],
      );
    } else {
      final winner = slots[higher].analysis!;
      final loser = slots[higher.other].analysis!;
      headline = InfoNote(
        icon: Icons.trending_up_rounded,
        title: higherTitle(higher),
        lines: [
          '${_scoreText(winner.score.total)} vs '
              '${_scoreText(loser.score.total)} '
              '(+${comparison.difference!.abs().toStringAsFixed(1)} points) '
              'for ${settingsLabel(winner.competitors.query)}.',
          ..._reasonLines(criterionDifferences(winner, loser), 'Why:'),
          'This only reflects what is mapped on OpenStreetMap. Visit both '
              'spots before deciding.',
        ],
        tone: NoteTone.positive,
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
          InfoNote(
            icon: Icons.warning_amber_rounded,
            lines: [warning],
            tone: NoteTone.warning,
          ),
        ],
      ],
    );
  }

  /// "The second location scores higher on the map".
  static String higherTitle(CompareSlot slot) =>
      '${slot.title} scores higher on the map';

  /// One line per criterion gap, from the named location's point of view.
  static List<String> _reasonLines(
    List<CriterionDifference> differences,
    String heading,
  ) {
    if (differences.isEmpty) return const [];
    return [
      heading,
      for (final d in differences)
        '• ${_reasonText(d)} '
            '(${d.points > 0 ? '+' : '−'}${d.points.abs().toStringAsFixed(1)} '
            'points)',
    ];
  }

  static String _reasonText(CriterionDifference d) {
    final gains = d.points > 0;
    return switch (d.criterion) {
      Criterion.competitorProximity =>
        gains
            ? 'Fewer similar businesses mapped nearby'
            : 'More similar businesses mapped nearby',
      Criterion.complementary =>
        gains
            ? 'More helpful places (schools, markets, banks…) mapped nearby'
            : 'Fewer helpful places mapped nearby',
      Criterion.roadAccess =>
        gains ? 'Closer to mapped roads' : 'Farther from mapped roads',
    };
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(child: child);
}

/// "64 / 100" or "No score yet".
String _scoreText(double? total) =>
    total == null ? 'No score yet' : '${total.round()} / 100';

TextStyle? _muted(BuildContext context) => mutedSmall(context);

final _compact = ButtonStyle(
  minimumSize: WidgetStateProperty.all(const Size(0, 48)),
);

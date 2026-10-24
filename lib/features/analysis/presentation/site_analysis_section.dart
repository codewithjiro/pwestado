import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/models/selected_site.dart';
import '../../../shared/widgets/elapsed_wait.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../discovery/domain/competitors.dart';
import '../../discovery/presentation/competitor_results.dart';
import '../../discovery/presentation/source_labels.dart';
import '../../discovery/state/competitor_controller.dart';
import '../../explore/state/explore_controller.dart';
import '../../saved/state/saved_analyses_controller.dart';
import '../domain/site_analysis.dart';
import '../domain/site_context.dart';
import '../domain/suitability_scoring.dart';
import '../state/analysis_controller.dart';

/// The location suitability card shown once a competitor search finishes:
/// an "Analyze" action, then the 40/30/30 heuristic breakdown.
class SiteAnalysisSection extends ConsumerWidget {
  const SiteAnalysisSection({super.key});

  static const title = 'Location suitability';
  static const insufficientData = 'Insufficient data';
  static const sampleLabel = 'Sample heuristic result';
  static const analyzeLabel = 'Analyze this site';
  static const disclaimer =
      'A preliminary heuristic from mapped OpenStreetMap evidence. It is not '
      'a prediction of sales, customer demand, foot traffic, profit, or '
      'business success.';
  static const assumptionsNote =
      'These thresholds are developer assumptions for this prototype, not '
      'research-backed values. Compare sites only with the same business '
      'type and radius.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitorStatus = ref.watch(
      competitorControllerProvider.select((s) => s.status),
    );
    final hasResult = ref.watch(
      competitorControllerProvider.select((s) => s.result != null),
    );
    final analysis = ref.watch(analysisControllerProvider);
    final controller = ref.read(analysisControllerProvider.notifier);

    final Widget body;
    if (competitorStatus == CompetitorStatus.error) {
      body = const _CompetitorsMissing();
    } else if (!hasResult) {
      return const SizedBox.shrink();
    } else {
      body = switch (analysis.status) {
        AnalysisStatus.idle => _Intro(onAnalyze: controller.analyze),
        AnalysisStatus.loading => _Loading(onCancel: controller.cancel),
        AnalysisStatus.ready => ScoreBreakdown(
          analysis: analysis.analysis!,
          onRefresh: () => controller.analyze(forceRefresh: true),
          actions: SaveAnalysisButton(analysis: analysis.analysis!),
        ),
      };
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: body,
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onAnalyze});

  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Adds one OpenStreetMap request for complementary places and '
            'mapped roads near this site, then scores it: 40% competitor '
            'proximity, 30% complementary places, 30% road-access proxy.',
            style: _muted(context),
          ),
          const SizedBox(height: AppSpacing.md),
          const _WeightStrip(),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.tonalIcon(
            onPressed: onAnalyze,
            icon: const Icon(Icons.analytics_outlined),
            label: const Text(SiteAnalysisSection.analyzeLabel),
          ),
        ],
      ),
    );
  }
}

/// The fixed 40/30/30 weights as a labeled strip.
class _WeightStrip extends StatelessWidget {
  const _WeightStrip();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: BrandColors.emerald900,
      fontWeight: FontWeight.w700,
    );
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final (i, criterion) in Criterion.values.indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              flex: criterion.weightPercent,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _criterionTint(criterion),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${criterion.weightPercent}% ${_shortLabel(criterion)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Fetching complementary places and nearby roads…',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: const LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: BrandColors.mintSoft,
              semanticsLabel: 'Fetching scoring evidence',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const ElapsedWait(),
          Text(
            'One more Overpass request. Shared servers can take up to a '
            'minute to answer.',
            style: _muted(context),
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

class _CompetitorsMissing extends StatelessWidget {
  const _CompetitorsMissing();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading(),
          const SizedBox(height: AppSpacing.md),
          const _TotalLine(score: null),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The competitor search did not return data, so no score is '
            'calculated. Try the search again or use sample demo data.',
            style: _muted(context),
          ),
        ],
      ),
    );
  }
}

/// Saves an analysis to Saved Analyses, only on explicit request.
class SaveAnalysisButton extends ConsumerWidget {
  const SaveAnalysisButton({super.key, required this.analysis, this.site});

  static const label = 'Save analysis';
  static const savedLabel = 'Saved · view';

  final SiteAnalysis analysis;

  /// The site to record. Defaults to the map's current site, which is the
  /// one the main-screen analysis describes.
  final SelectedSite? site;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site =
        this.site ?? ref.watch(exploreControllerProvider.select((s) => s.site));
    final savedId = ref.watch(
      savedAnalysesControllerProvider.select((s) => s.savedIds[analysis]),
    );
    if (site == null) return const SizedBox.shrink();

    if (savedId != null) {
      return OutlinedButton.icon(
        onPressed: () => context.go(AppRoutes.savedDetail(savedId)),
        icon: const Icon(Icons.bookmark_added, size: 20),
        label: const Text(savedLabel),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => saveAnalysis(context, ref, site, analysis),
      icon: const Icon(Icons.bookmark_add_outlined, size: 20),
      label: const Text(label),
    );
  }
}

/// Saves [analysis] and reports the outcome in a snackbar with a "View"
/// action.
Future<void> saveAnalysis(
  BuildContext context,
  WidgetRef ref,
  SelectedSite site,
  SiteAnalysis analysis,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final outcome = await ref
      .read(savedAnalysesControllerProvider.notifier)
      .save(site, analysis);
  final id = outcome.id;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          id != null
              ? 'Analysis saved on this device with its original evidence '
                    'and times.'
              : outcome.error ?? 'Could not save the analysis.',
        ),
        action: id == null
            ? null
            : SnackBarAction(
                label: 'View',
                onPressed: () => router.go(AppRoutes.savedDetail(id)),
              ),
      ),
    );
}

/// Total, warnings, per-criterion breakdown, formula, rules, and sources.
class ScoreBreakdown extends StatelessWidget {
  const ScoreBreakdown({
    super.key,
    required this.analysis,
    this.onRefresh,
    this.actions,
  });

  final SiteAnalysis analysis;

  /// Re-requests the evidence. Null for saved, historical results, which
  /// are never refreshed in place.
  final VoidCallback? onRefresh;

  /// Optional row under the total, e.g. the save button.
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = analysis.score;
    final query = analysis.competitors.query;
    final formula = score.formula;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(
            trailing: !analysis.isSample && onRefresh != null
                ? IconButton(
                    tooltip: 'Refresh scoring evidence',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    color: BrandColors.emerald700,
                  )
                : null,
          ),
          if (analysis.isSample) ...[
            const SizedBox(height: AppSpacing.sm),
            const _SampleTag(),
          ],
          const SizedBox(height: AppSpacing.lg),
          _TotalLine(
            score: score.total,
            lowConfidence: score.lowConfidence,
            settings: '${query.category.label} · ${query.radius.label}',
          ),
          const SizedBox(height: AppSpacing.md),
          _ContributionBar(score: score),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${query.category.label} within ${query.radius.label}. '
            '${SiteAnalysisSection.disclaimer}',
            style: _muted(context),
          ),
          if (actions != null) ...[
            const SizedBox(height: AppSpacing.md),
            actions!,
          ],
          if (score.warnings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Warnings(warnings: score.warnings),
          ],
          const SizedBox(height: AppSpacing.lg),
          for (final criterion in score.criteria) ...[
            _CriterionRow(result: criterion),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (formula != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: BrandColors.offWhite,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Total = $formula',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: BrandColors.emerald900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          _Rules(analysis: analysis),
          const Divider(height: AppSpacing.xl),
          _Sources(analysis: analysis, onRetry: onRefresh),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.score,
    this.lowConfidence = false,
    this.settings,
  });

  final double? score;
  final bool lowConfidence;
  final String? settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = this.score;
    if (score == null) {
      return Row(
        children: [
          const _Gauge(value: null),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              SiteAnalysisSection.insufficientData,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: BrandColors.inkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }
    return Semantics(
      label: 'Suitability score ${score.round()} out of 100',
      child: Row(
        children: [
          ExcludeSemantics(child: _Gauge(value: score)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HEURISTIC SCORE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: BrandColors.emerald700,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${score.round()}',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: BrandColors.emerald900,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: ' / 100',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: BrandColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (settings != null)
                        Text(settings!, style: _muted(context)),
                    ],
                  ),
                ),
                if (lowConfidence) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const StatusPill(
                    label: 'Low confidence',
                    icon: Icons.warning_amber_rounded,
                    background: BrandColors.amberWash,
                    foreground: BrandColors.amberInk,
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

/// Ring gauge for the total out of 100; an empty grey ring without one.
class _Gauge extends StatelessWidget {
  const _Gauge({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return SizedBox.square(
      dimension: 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (value ?? 0) / 100),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: value == null
                  ? BrandColors.outlineSoft
                  : BrandColors.mintSoft,
              color: BrandColors.emerald700,
            ),
          ),
          Center(
            child: Icon(
              value == null ? Icons.help_outline : Icons.place_rounded,
              color: value == null
                  ? BrandColors.inkMuted
                  : BrandColors.emerald700,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stacked bar: how many of each criterion's possible points were earned.
class _ContributionBar extends StatelessWidget {
  const _ContributionBar({required this.score});

  final SuitabilityScore score;

  @override
  Widget build(BuildContext context) {
    final legend = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: BrandColors.inkMuted,
      fontWeight: FontWeight.w600,
    );
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final (i, result) in score.criteria.indexed) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  flex: result.criterion.weightPercent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 10,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: _criterionTint(result.criterion)),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (result.score ?? 0) / 100,
                            child: ColoredBox(
                              color: _criterionColor(result.criterion),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final (i, result) in score.criteria.indexed) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  flex: result.criterion.weightPercent,
                  child: Text(
                    '${_shortLabel(result.criterion)} '
                    '${result.contribution?.toStringAsFixed(1) ?? '—'}/'
                    '${result.criterion.weightPercent}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: legend,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({required this.result});

  final CriterionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = result.score;
    final criterion = result.criterion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _criterionIcon(criterion),
              size: 20,
              color: _criterionColor(criterion),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${criterion.label} · ${criterion.weightPercent}%',
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              score == null ? 'No data' : '${score.round()} / 100',
              style: theme.textTheme.labelLarge?.copyWith(
                color: score == null
                    ? BrandColors.inkMuted
                    : BrandColors.emerald700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          // Without a score the empty bar says nothing; "No data" is read
          // from the text above instead.
          child: ExcludeSemantics(
            excluding: score == null,
            child: LinearProgressIndicator(
              value: (score ?? 0) / 100,
              minHeight: 8,
              backgroundColor: _criterionTint(criterion),
              color: _criterionColor(criterion),
              semanticsLabel: '${criterion.label} score',
              semanticsValue: '${(score ?? 0).round()}',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          score == null
              ? 'Adds nothing: evidence unavailable.'
              : 'Adds ${result.contribution!.toStringAsFixed(1)} of '
                    '${criterion.weightPercent} possible points.',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: BrandColors.emerald900,
          ),
        ),
        Text(result.evidence, style: theme.textTheme.bodySmall),
        Text(criterion.meaning, style: _muted(context)),
      ],
    );
  }
}

class _Warnings extends StatelessWidget {
  const _Warnings({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: SampleBanner.foreground);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SampleBanner.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: BrandColors.amberEdge.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: SampleBanner.foreground,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(warning, style: style)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules({required this.analysis});

  final SiteAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = ComplementaryTags.forCategory(
      analysis.competitors.query.category,
    ).map((t) => '${t.$1}=${t.$2}').join(', ');
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: const Icon(Icons.functions, color: BrandColors.emerald700),
        title: Text(
          'How the score is calculated',
          style: theme.textTheme.titleSmall?.copyWith(
            color: BrandColors.emerald700,
          ),
        ),
        children: [
          Text(
            'Total = 0.40 × competitor + 0.30 × complementary + 0.30 × road '
            'proxy. Each criterion is scaled 0 to 100.',
            style: theme.textTheme.bodySmall,
          ),
          for (final result in analysis.score.criteria) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(result.criterion.label, style: theme.textTheme.labelLarge),
            Text(result.rule, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Complementary tags counted: $tags. The selected business tag is '
            'excluded. Roads counted: mapped highway=${RoadKinds.all.join('/')} '
            'ways.',
            style: _muted(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(SiteAnalysisSection.assumptionsNote, style: _muted(context)),
        ],
      ),
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.analysis, required this.onRetry});

  final SiteAnalysis analysis;

  /// Null for saved results: their failed request is history, not retried.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = _muted(context);
    final siteContext = analysis.context;
    final failure = analysis.contextFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Evidence sources', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        _SourceRow(
          label: 'Competitors',
          source: analysis.competitors.source,
          text: _describe(
            context,
            analysis.competitors.source,
            analysis.competitors.fetchedAt,
          ),
        ),
        if (siteContext != null)
          _SourceRow(
            label: 'Complementary places & roads',
            source: siteContext.source,
            text:
                _describe(context, siteContext.source, siteContext.fetchedAt) +
                (siteContext.skippedCount > 0
                    ? ' ${siteContext.skippedCount} records skipped for '
                          'missing coordinates.'
                    : ''),
          )
        else if (failure != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Complementary places & roads: '
            '${describeOverpassFailure(failure, analysis.contextStatusCode).$1}. '
            'Nothing was substituted for the missing evidence.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          analysis.isSample
              ? CompetitorResults.sampleNote
              : CompetitorResults.attribution,
          style: muted,
        ),
      ],
    );
  }

  static String _describe(
    BuildContext context,
    DataSource source,
    DateTime fetchedAt,
  ) {
    final when = formatFetchedAt(context, fetchedAt);
    return switch (source) {
      DataSource.live => 'Retrieved live $when from OpenStreetMap.',
      DataSource.cached => 'Cached copy of a response retrieved $when.',
      DataSource.sample => 'Fictional sample data created $when.',
    };
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.label,
    required this.source,
    required this.text,
  });

  final String label;
  final DataSource source;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              SourceBadge(source: source),
            ],
          ),
          Text(text, style: _muted(context)),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SectionHeader(
      icon: Icons.insights_outlined,
      title: SiteAnalysisSection.title,
      subtitle: 'Weighted 40 / 30 / 30 heuristic',
      trailing: trailing,
    );
  }
}

class _SampleTag extends StatelessWidget {
  const _SampleTag();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: StatusPill(
        label: SiteAnalysisSection.sampleLabel,
        icon: Icons.science_outlined,
        background: SampleBanner.background,
        foreground: SampleBanner.foreground,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(child: child);
}

String _shortLabel(Criterion criterion) => switch (criterion) {
  Criterion.competitorProximity => 'Competition',
  Criterion.complementary => 'Complements',
  Criterion.roadAccess => 'Roads',
};

IconData _criterionIcon(Criterion criterion) => switch (criterion) {
  Criterion.competitorProximity => Icons.storefront_outlined,
  Criterion.complementary => Icons.diversity_3_outlined,
  Criterion.roadAccess => Icons.add_road_outlined,
};

Color _criterionColor(Criterion criterion) => switch (criterion) {
  Criterion.competitorProximity => BrandColors.emerald900,
  Criterion.complementary => BrandColors.emerald500,
  Criterion.roadAccess => BrandColors.emerald300,
};

Color _criterionTint(Criterion criterion) => switch (criterion) {
  Criterion.competitorProximity => const Color(0xFFD3E6DE),
  Criterion.complementary => BrandColors.mintSoft,
  Criterion.roadAccess => BrandColors.mintWash,
};

TextStyle? _muted(BuildContext context) => mutedSmall(context);

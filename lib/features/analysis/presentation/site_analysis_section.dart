import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/elapsed_wait.dart';
import '../../discovery/domain/competitors.dart';
import '../../discovery/presentation/competitor_results.dart';
import '../../discovery/presentation/source_labels.dart';
import '../../discovery/state/competitor_controller.dart';
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
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Adds one OpenStreetMap request for complementary places and '
            'mapped roads near this site, then scores it: 40% competitor '
            'proximity, 30% complementary places, 30% road-access proxy.',
            style: _muted(context),
          ),
          const SizedBox(height: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Fetching complementary places and nearby roads…',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          const LinearProgressIndicator(
            semanticsLabel: 'Fetching scoring evidence',
          ),
          const SizedBox(height: AppSpacing.sm),
          const ElapsedWait(),
          Text(
            'One more Overpass request. Shared servers can take up to a '
            'minute to answer.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: BrandColors.inkMuted),
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
          const SizedBox(height: AppSpacing.sm),
          const _TotalLine(score: null),
          const SizedBox(height: AppSpacing.xs),
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

/// Total, warnings, per-criterion breakdown, formula, rules, and sources.
class ScoreBreakdown extends StatelessWidget {
  const ScoreBreakdown({
    super.key,
    required this.analysis,
    required this.onRefresh,
  });

  final SiteAnalysis analysis;
  final VoidCallback onRefresh;

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
          Row(
            children: [
              const Expanded(child: _Heading()),
              if (!analysis.isSample)
                IconButton(
                  tooltip: 'Refresh scoring evidence',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  color: BrandColors.emerald700,
                ),
            ],
          ),
          if (analysis.isSample) ...[
            const SizedBox(height: AppSpacing.sm),
            const _SampleTag(),
          ],
          const SizedBox(height: AppSpacing.sm),
          _TotalLine(score: score.total, lowConfidence: score.lowConfidence),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${query.category.label} within ${query.radius.label}. '
            '${SiteAnalysisSection.disclaimer}',
            style: _muted(context),
          ),
          if (score.warnings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Warnings(warnings: score.warnings),
          ],
          const SizedBox(height: AppSpacing.lg),
          for (final criterion in score.criteria) ...[
            _CriterionRow(result: criterion),
            const SizedBox(height: AppSpacing.md),
          ],
          if (formula != null) ...[
            Text('Total = $formula', style: theme.textTheme.labelLarge),
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
  const _TotalLine({required this.score, this.lowConfidence = false});

  final double? score;
  final bool lowConfidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = this.score;
    if (score == null) {
      return Text(
        SiteAnalysisSection.insufficientData,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: BrandColors.inkMuted,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Semantics(
      label: 'Suitability score ${score.round()} out of 100',
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${score.round()}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: BrandColors.emerald900,
                    fontWeight: FontWeight.w800,
                    height: 1,
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
          if (lowConfidence)
            const _Pill(
              label: 'Low confidence',
              icon: Icons.warning_amber_rounded,
              background: Color(0xFFFFF1C2),
              foreground: Color(0xFF6B4A00),
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
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          // Without a score the empty bar says nothing; "No data" is read
          // from the text above instead.
          child: ExcludeSemantics(
            excluding: score == null,
            child: LinearProgressIndicator(
              value: (score ?? 0) / 100,
              minHeight: 8,
              backgroundColor: BrandColors.outline,
              color: BrandColors.emerald500,
              semanticsLabel: '${criterion.label} score',
              semanticsValue: '${(score ?? 0).round()}',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          score == null
              ? 'Adds nothing: evidence unavailable.'
              : 'Adds ${result.contribution!.toStringAsFixed(1)} of '
                    '${criterion.weightPercent} possible points.',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
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
  final VoidCallback onRetry;

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
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
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
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
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
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.insights_outlined, color: BrandColors.emerald700),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            SiteAnalysisSection.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _SampleTag extends StatelessWidget {
  const _SampleTag();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: _Pill(
        label: SiteAnalysisSection.sampleLabel,
        icon: Icons.science_outlined,
        background: SampleBanner.background,
        foreground: SampleBanner.foreground,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
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
    // A Material (not a decorated box) so the expansion tile's ink shows.
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

TextStyle? _muted(BuildContext context) => Theme.of(
  context,
).textTheme.bodySmall?.copyWith(color: BrandColors.inkMuted);

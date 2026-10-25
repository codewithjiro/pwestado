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

  static const title = 'Location suitability score';
  static const subtitle = 'Based on limited map data';
  static const insufficientData = 'Not enough data yet';
  static const insufficientMessage =
      'We couldn’t get enough information to score this location yet.';
  static const reasonsTitle = 'Main reasons';
  static const limitsTitle = 'What this score can’t tell you';
  static const technicalTitle = 'How the score is calculated';
  static const sampleLabel = 'Sample result · not real data';
  static const analyzeLabel = 'Calculate suitability score';
  static const lowConfidenceLabel = 'May be incomplete';
  static const disclaimer =
      'This score is based on limited mapped evidence from OpenStreetMap. It '
      'does not predict sales, customer demand, foot traffic, profit or '
      'business success.';
  static const assumptionsNote =
      'These thresholds are simple starting assumptions for this prototype, '
      'not research-backed values. Only compare locations that use the same '
      'business type and radius.';

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
            'Next, we check helpful places (like schools, markets and banks) '
            'and roads near this spot on OpenStreetMap, then combine them '
            'with the similar businesses found. The score is out of 100: '
            '40% competition, 30% helpful places, 30% roads.',
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
      color: context.palette.heading,
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
                  color: _criterionTint(context, criterion),
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
            'Checking helpful places and roads nearby…',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: context.palette.accentContainer,
              semanticsLabel: 'Fetching scoring evidence',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const ElapsedWait(),
          Text(
            'This uses a free public map server, so it can take up to a '
            'minute. Thanks for waiting!',
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
            'The business search didn’t finish, so there’s nothing to score '
            'yet. Try the search again, or use sample demo data to see how it '
            'works.',
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
  static const savingLabel = 'Saving…';

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
    final saving = ref.watch(
      savedAnalysesControllerProvider.select((s) => s.isSaving(analysis)),
    );
    if (site == null) return const SizedBox.shrink();

    if (saving) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text(savingLabel),
      );
    }

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
              ? 'Analysis saved on this phone. Find it any time in SAVED.'
              : '${outcome.error ?? 'Could not save the analysis.'} Your '
                    'result is still here, so you can try saving again.',
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
    final score = analysis.score;
    final query = analysis.competitors.query;
    final total = score.total;

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
                    color: context.palette.brand,
                  )
                : null,
          ),
          if (analysis.isSample) ...[
            const SizedBox(height: AppSpacing.sm),
            const _SampleTag(),
          ],
          // 1. Plain-language summary.
          const SizedBox(height: AppSpacing.lg),
          _TotalLine(
            score: score.total,
            lowConfidence: score.lowConfidence,
            settings: '${query.category.label} · within ${query.radius.label}',
          ),
          if (total != null) ...[
            const SizedBox(height: AppSpacing.md),
            ScoreInterpretation(total: total, score: score),
          ],
          // 2. The main reasons, one per criterion.
          const SizedBox(height: AppSpacing.lg),
          const _SubHeading(SiteAnalysisSection.reasonsTitle),
          const SizedBox(height: AppSpacing.sm),
          for (final criterion in score.criteria) ...[
            _CriterionRow(result: criterion),
            const SizedBox(height: AppSpacing.lg),
          ],
          // 3. Limits of the data, always visible.
          const _SubHeading(SiteAnalysisSection.limitsTitle),
          const SizedBox(height: AppSpacing.sm),
          if (score.warnings.isNotEmpty) ...[
            _Warnings(warnings: score.warnings),
            const SizedBox(height: AppSpacing.sm),
          ],
          _MissingEvidence(analysis: analysis, onRetry: onRefresh),
          Text(
            'Counts only ${query.category.label.toLowerCase()} businesses '
            'and places mapped on OpenStreetMap within ${query.radius.label} '
            'around this spot. ${SiteAnalysisSection.disclaimer}',
            style: _muted(context),
          ),
          if (actions != null) ...[
            const SizedBox(height: AppSpacing.md),
            actions!,
          ],
          // 4. Formula, points and sources, collapsed by default.
          const SizedBox(height: AppSpacing.sm),
          _Rules(analysis: analysis),
        ],
      ),
    );
  }
}

/// A plain-language reading of the total. The bands are as much an
/// assumption as the thresholds, so the text always points back to the
/// evidence and to checking the area in person.
class ScoreInterpretation extends StatelessWidget {
  const ScoreInterpretation({super.key, required this.total, this.score});

  final double total;

  /// When given, the summary names what helped and what held the score
  /// back, in plain words.
  final SuitabilityScore? score;

  /// "Helped by: few similar businesses mapped nearby." and/or "Held back
  /// by: …", or nothing when no criterion stands out.
  static List<String> drivers(SuitabilityScore score) {
    final helped = <String>[];
    final heldBack = <String>[];
    for (final result in score.criteria) {
      final value = result.score;
      if (value == null) continue;
      if (value >= 60) helped.add(_plain(result.criterion, strong: true));
      if (value < 40) heldBack.add(_plain(result.criterion, strong: false));
    }
    return [
      if (helped.isNotEmpty) 'Helped by: ${helped.join('; ')}.',
      if (heldBack.isNotEmpty) 'Held back by: ${heldBack.join('; ')}.',
    ];
  }

  static String _plain(Criterion criterion, {required bool strong}) =>
      switch (criterion) {
        Criterion.competitorProximity =>
          strong
              ? 'few similar businesses mapped nearby'
              : 'many similar businesses mapped nearby',
        Criterion.complementary =>
          strong
              ? 'many helpful places mapped nearby'
              : 'few helpful places mapped nearby',
        Criterion.roadAccess =>
          strong ? 'a mapped road close by' : 'mapped roads far or missing',
      };

  static String headline(double total) => total >= 70
      ? 'Promising, based on what’s on the map'
      : total >= 45
      ? 'Mixed signals on the map'
      : 'Challenging, based on what’s on the map';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline(total),
          style: theme.textTheme.titleSmall?.copyWith(
            color: context.palette.brand,
          ),
        ),
        if (score != null)
          for (final line in drivers(score!))
            Text(line, style: theme.textTheme.bodySmall),
        Text(
          'Use it as a starting point. Visit the area at different times '
          'before deciding.',
          style: theme.textTheme.bodySmall,
        ),
      ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SiteAnalysisSection.insufficientData,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  SiteAnalysisSection.insufficientMessage,
                  style: theme.textTheme.bodySmall,
                ),
              ],
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
                        'SUITABILITY SCORE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: context.palette.brand,
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
                                color: context.palette.heading,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: ' / 100',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: context.palette.textSecondary,
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
                    label: SiteAnalysisSection.lowConfidenceLabel,
                    icon: Icons.warning_amber_rounded,
                    tone: Tone.warning,
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
                  ? context.palette.border
                  : context.palette.accentContainer,
              color: context.palette.brand,
            ),
          ),
          Center(
            child: Icon(
              value == null ? Icons.help_outline : Icons.place_rounded,
              color: value == null
                  ? context.palette.textSecondary
                  : context.palette.brand,
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
      color: context.palette.textSecondary,
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
                          ColoredBox(
                            color: _criterionTint(context, result.criterion),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (result.score ?? 0) / 100,
                            child: ColoredBox(
                              color: _criterionColor(context, result.criterion),
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
              color: _criterionColor(context, criterion),
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
                    ? context.palette.textSecondary
                    : context.palette.brand,
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
              backgroundColor: _criterionTint(context, criterion),
              color: _criterionColor(context, criterion),
              semanticsLabel: '${criterion.label} score',
              semanticsValue: '${(score ?? 0).round()}',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.evidence,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.palette.heading,
          ),
        ),
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
    ).textTheme.bodySmall?.copyWith(color: context.palette.sample);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.palette.sampleContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: context.palette.warningBorder.withValues(alpha: 0.5),
        ),
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
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: context.palette.sample,
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
        leading: Icon(Icons.functions, color: context.palette.brand),
        title: Text(
          SiteAnalysisSection.technicalTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            color: context.palette.brand,
          ),
        ),
        subtitle: Text(
          'Points, formula and data sources',
          style: _muted(context),
        ),
        children: [
          _ContributionBar(score: analysis.score),
          const SizedBox(height: AppSpacing.sm),
          for (final result in analysis.score.criteria)
            Text(
              result.score == null
                  ? '${result.criterion.label}: adds nothing (no data).'
                  : '${result.criterion.label}: adds '
                        '${result.contribution!.toStringAsFixed(1)} of '
                        '${result.criterion.weightPercent} possible points.',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Total = 0.40 × competition + 0.30 × helpful places + 0.30 × '
            'mapped roads. Each part is scored from 0 to 100.',
            style: theme.textTheme.bodySmall,
          ),
          if (analysis.score.formula != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: context.palette.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Total = ${analysis.score.formula}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: context.palette.heading,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
            ),
          ],
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
          const Divider(height: AppSpacing.xl),
          _Sources(analysis: analysis),
        ],
      ),
    );
  }
}

/// Small heading for a part of the result card.
class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: context.palette.heading),
      ),
    );
  }
}

/// A failed places-and-roads request, kept in view with its retry: it is
/// the reason a score may be missing, not a technical footnote.
class _MissingEvidence extends StatelessWidget {
  const _MissingEvidence({required this.analysis, required this.onRetry});

  final SiteAnalysis analysis;

  /// Null for saved results: their failed request is history, not retried.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = analysis.contextFailure;
    if (analysis.context != null || failure == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Helpful places and roads couldn’t be loaded: '
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
      ),
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.analysis});

  final SiteAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = _muted(context);
    final siteContext = analysis.context;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Evidence sources', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        _SourceRow(
          label: 'Similar businesses',
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
        else
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Complementary places & roads: not loaded (see above).',
              style: muted,
            ),
          ),
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
      subtitle: SiteAnalysisSection.subtitle,
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
        tone: Tone.sample,
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
  Criterion.complementary => 'Places',
  Criterion.roadAccess => 'Roads',
};

IconData _criterionIcon(Criterion criterion) => switch (criterion) {
  Criterion.competitorProximity => Icons.storefront_outlined,
  Criterion.complementary => Icons.diversity_3_outlined,
  Criterion.roadAccess => Icons.add_road_outlined,
};

/// Criterion colors come from the palette, in 40/30/30 order.
Color _criterionColor(BuildContext context, Criterion criterion) =>
    context.palette.criterion[criterion.index];

Color _criterionTint(BuildContext context, Criterion criterion) =>
    context.palette.criterionTint[criterion.index];

TextStyle? _muted(BuildContext context) => mutedSmall(context);

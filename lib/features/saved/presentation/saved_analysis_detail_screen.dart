import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/geo.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../analysis/presentation/site_analysis_section.dart';
import '../../comparison/domain/site_comparison.dart';
import '../../comparison/state/comparison_controller.dart';
import '../../discovery/domain/competitors.dart';
import '../../discovery/presentation/source_labels.dart';
import '../../explore/state/explore_controller.dart';
import '../../places/presentation/site_place_label.dart';
import '../domain/saved_analysis.dart';
import '../state/saved_analyses_controller.dart';
import 'saved_widgets.dart';

/// One saved analysis, reopened offline. Shows the stored score and
/// breakdown, original sources and retrieval times, and the stored
/// competitor records. Nothing is refreshed from here.
class SavedAnalysisDetailScreen extends ConsumerWidget {
  const SavedAnalysisDetailScreen({super.key, required this.id});

  final int id;

  static const historicalTitle = 'Historical saved result';
  static const useAsA = 'Compare as first location';
  static const useAsB = 'Compare as second location';
  static const openOnMap = 'Open this spot on the map';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedAnalysisProvider(id));

    void back() =>
        context.canPop() ? context.pop() : context.go(AppRoutes.saved);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved analysis'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: back,
        ),
        actions: [
          IconButton(
            tooltip: 'Delete saved analysis',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              back();
              deleteSavedWithUndo(context, ref, id);
            },
          ),
        ],
      ),
      body: saved.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Opening saved analysis',
          ),
        ),
        error: (error, _) => _LoadError(error: error, onBack: back),
        data: (saved) => _Body(saved: saved),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.saved});

  final SavedAnalysis saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final analysis = saved.analysis;
    final query = analysis.competitors.query;
    final retrieved = oldestFetch(analysis);
    final muted = mutedSmall(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        // Historical banner: this is not a fresh analysis.
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [BrandColors.emerald800, BrandColors.emerald900],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    color: context.palette.onBrandFill,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      SavedAnalysisDetailScreen.historicalTitle.toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: context.palette.onBrandFill,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  SavedSourceBadge(source: saved.source),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Saved ${formatSavedDate(context, saved.savedAt)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              Text(
                'Evidence originally retrieved '
                '${formatSavedDate(context, retrieved)}. Opened from this '
                'device without a new request and never refreshed. '
                'Businesses may have opened, closed, or been mapped since.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        if (analysis.isSample) ...[
          const SizedBox(height: AppSpacing.md),
          const SampleBanner(),
        ],
        if (!saved.scoreMatchesSaved) ...[
          const SizedBox(height: AppSpacing.md),
          InfoNote(
            icon: Icons.rule,
            tone: NoteTone.warning,
            title: 'Scoring rules changed since saving',
            lines: [
              'Saved total: ${_total(saved.savedTotal)}. Recalculated with '
                  'the current rules from the same evidence: '
                  '${_total(analysis.score.total)}.',
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                icon: query.category.icon,
                title: '${query.category.label} · ${query.radius.label}',
              ),
              const SizedBox(height: AppSpacing.md),
              // Looked up when the record is opened; never stored. Offline,
              // it falls back to "Selected location" with a Retry.
              SitePlaceLabel(site: saved.site),
              SiteTechnicalDetails(site: saved.site),
              const SizedBox(height: AppSpacing.lg),
              Text('Use this saved result', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  for (final slot in CompareSlot.values) ...[
                    if (slot == CompareSlot.b)
                      const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () => _useInSlot(context, ref, slot),
                        icon: const Icon(Icons.compare_arrows, size: 18),
                        label: Text(
                          slot == CompareSlot.a
                              ? SavedAnalysisDetailScreen.useAsA
                              : SavedAnalysisDetailScreen.useAsB,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => _openOnMap(context, ref),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text(SavedAnalysisDetailScreen.openOnMap),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Comparing uses this saved result exactly as it was saved. '
                'Opening the spot on the map doesn’t search by itself; tap '
                '"Find nearby businesses" there for today’s map data.',
                style: muted,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ScoreBreakdown(analysis: analysis),
        const SizedBox(height: AppSpacing.md),
        _StoredCompetitors(result: analysis.competitors),
      ],
    );
  }

  static String _total(double? total) =>
      total == null ? 'No score' : '${total.toStringAsFixed(1)} / 100';

  /// Aligns the search settings with the saved record, then puts it in
  /// [slot] so the existing comparison rules apply to it unchanged.
  void _useInSlot(BuildContext context, WidgetRef ref, CompareSlot slot) {
    final query = saved.analysis.competitors.query;
    final switched = ref
        .read(exploreControllerProvider.notifier)
        .applySettings(query.category, query.radius);
    ref.read(comparisonControllerProvider.notifier).loadSaved(slot, saved);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'This saved result is now the ${slot.title.toLowerCase()}.'
            '${switched ? ' Search settings switched to ${settingsLabel(query)} to match it.' : ''}',
          ),
        ),
      );
    context.go(AppRoutes.compare);
  }

  void _openOnMap(BuildContext context, WidgetRef ref) {
    final query = saved.analysis.competitors.query;
    final explore = ref.read(exploreControllerProvider.notifier);
    explore.applySettings(query.category, query.radius);
    explore.selectSite(latitude: query.latitude, longitude: query.longitude);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Saved spot placed on the map. Tap "Find nearby businesses" '
            'for today’s OpenStreetMap data.',
          ),
        ),
      );
    context.go(AppRoutes.explore);
  }
}

/// The competitor records exactly as stored, nearest first.
class _StoredCompetitors extends StatefulWidget {
  const _StoredCompetitors({required this.result});

  final CompetitorResult result;

  @override
  State<_StoredCompetitors> createState() => _StoredCompetitorsState();
}

class _StoredCompetitorsState extends State<_StoredCompetitors> {
  static const _initialRows = 15;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final businesses = result.businesses;
    final visible = _showAll || businesses.length <= _initialRows
        ? businesses
        : businesses.take(_initialRows).toList();
    final isSample = result.source == DataSource.sample;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            icon: Icons.storefront_outlined,
            iconBackground: context.palette.competitorContainer,
            iconColor: context.palette.competitor,
            title: isSample
                ? '${result.count} sample businesses'
                : '${result.count} '
                      '${result.count == 1 ? 'business' : 'businesses'} found',
            subtitle:
                'As saved · ${result.query.category.label} within '
                '${result.query.radius.label}',
          ),
          const SizedBox(height: AppSpacing.md),
          if (businesses.isEmpty)
            Text(
              'No businesses were found on the map within this radius when it '
              'was saved.',
              style: mutedSmall(context),
            ),
          for (final (index, business) in visible.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                  const CompetitorDot(size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      business.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: business.name == null
                            ? FontStyle.italic
                            : null,
                        color: business.name == null
                            ? context.palette.textSecondary
                            : null,
                      ),
                    ),
                  ),
                  Text(
                    formatDistance(business.distanceMeters),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: context.palette.brand,
                    ),
                  ),
                ],
              ),
            ),
          if (visible.length < businesses.length)
            TextButton(
              onPressed: () => setState(() => _showAll = true),
              child: Text('Show all ${businesses.length}'),
            ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onBack});

  final Object error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (error) {
      SavedAnalysisNotFoundException() => (
        'Saved analysis not found',
        'It may have been deleted.',
      ),
      SavedAnalysisCorruptException() => (
        'This saved record could not be read',
        'Its stored evidence is damaged, so no score is shown and nothing is '
            'guessed. You can delete it from the saved list.',
      ),
      SavedAnalysisStorageException(:final message) => (
        'Saved analyses are unavailable',
        message,
      ),
      _ => ('Could not open this analysis', 'Please try again.'),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sd_card_alert_outlined,
              size: 48,
              color: context.palette.brand,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: mutedSmall(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(onPressed: onBack, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}

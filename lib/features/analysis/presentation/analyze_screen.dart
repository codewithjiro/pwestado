import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/tab_page.dart';
import '../../ai/data/ai_payload.dart';
import '../../ai/presentation/ai_insights_card.dart';
import '../../discovery/presentation/competitor_results.dart';
import '../../discovery/presentation/competitor_summary.dart';
import '../../discovery/state/competitor_controller.dart';
import '../../explore/state/explore_controller.dart';
import '../../places/presentation/selected_site_card.dart';
import '../../places/state/place_providers.dart';
import '../state/analysis_controller.dart';
import 'site_analysis_section.dart';

/// ANALYZE tab: the chosen site, its competitor search, then the 40/30/30
/// suitability score. Each missing prerequisite is explained with the one
/// action that fixes it.
class AnalyzeScreen extends ConsumerWidget {
  const AnalyzeScreen({super.key});

  static const noSiteTitle = 'Choose a location first';
  static const findFirstTitle = 'Find nearby businesses';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final explore = ref.watch(exploreControllerProvider);
    final competitors = ref.watch(competitorControllerProvider);
    final site = explore.site;
    final analysis = ref.watch(analysisControllerProvider).analysis;

    final List<Widget> body;
    if (site == null) {
      body = [
        GuidanceCard(
          icon: Icons.add_location_alt_outlined,
          title: noSiteTitle,
          message:
              'The score is for one specific spot. On MAPA, search for a '
              'place, use your current location, or pick a spot on the map.',
          action: FilledButton.icon(
            onPressed: () => context.go(AppRoutes.explore),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Go to MAPA'),
          ),
        ),
      ];
    } else {
      body = [
        SelectedSiteCard(site: site),
        const SizedBox(height: AppSpacing.md),
        switch (competitors.status) {
          CompetitorStatus.idle => GuidanceCard(
            step: 1,
            icon: Icons.travel_explore,
            title: findFirstTitle,
            message:
                '${competitors.clearedNotice == null ? '' : '${competitors.clearedNotice} '}'
                'First, find which ${explore.category.label.toLowerCase()} '
                'businesses are on the map within ${explore.radius.label} '
                'around this spot. This can take up to a minute.',
            action: FilledButton.icon(
              onPressed: () =>
                  ref.read(competitorControllerProvider.notifier).search(),
              icon: const Icon(Icons.travel_explore),
              label: const Text(findFirstTitle),
            ),
          ),
          // Loading and failures: the shared results card has Cancel,
          // Try again and the labeled sample-data option.
          CompetitorStatus.loading ||
          CompetitorStatus.error => const CompetitorResults(),
          _ => const CompetitorSummary(),
        },
        // After a result, the score card; after a failed search, its
        // "Insufficient data" state (nothing is scored without evidence).
        if (competitors.result != null ||
            competitors.status == CompetitorStatus.error)
          const SiteAnalysisSection(),
        if (analysis != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AiInsightsCard(
            payload: AiPayload.canExplain(analysis)
                ? AiPayload.site(
                    analysis,
                    area: ref
                        .watch(placeLabelProvider(pointOf(site)))
                        .value
                        ?.subtitle,
                  )
                : null,
          ),
        ],
      ];
    }

    return TabPage(
      title: 'Analyze',
      subtitle: 'How suitable is this spot for your business?',
      children: body,
    );
  }
}

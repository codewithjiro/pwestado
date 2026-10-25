import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/config/mapbox_config.dart';
import '../../../../core/models/business_category.dart';
import '../../../../core/models/selected_site.dart';
import '../../../../shared/widgets/category_art.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../analysis/state/analysis_controller.dart';
import '../../../discovery/presentation/competitor_summary.dart';
import '../../../discovery/state/competitor_controller.dart';
import '../../../places/presentation/site_place_label.dart';
import '../../state/explore_controller.dart';
import 'business_type_picker.dart';
import 'search_distance_picker.dart';

/// The map tab's compact controls, in the order a first-time user needs
/// them: where (location), what (business type), how far (radius), then
/// "Find nearby businesses" and, once found, the next step to the score.
class MapSetupCard extends ConsumerWidget {
  const MapSetupCard({super.key});

  static const findLabel = 'Find nearby businesses';
  static const noSiteTitle = 'Choose a location';
  static const noSiteHint =
      'Search above, use your location, or pick a spot on the map.';
  static const needSiteReason = 'Choose a location first, then search.';
  static const useMyLocation = 'Use my location';
  static const pickOnMap = 'Pick on map';

  /// Starts the score calculation (one explicit request) and opens it.
  static const openAnalyze = 'Calculate suitability score';

  /// Opens the score that is already being calculated or is ready.
  static const viewScore = 'See the suitability score';
  static const viewProgress = 'See score progress';
  static const businessTypeLabel = 'Business type';

  /// Below this content width the distance field moves under the business
  /// type instead of squeezing it.
  static const _sideBySideMinWidth = 340.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exploreControllerProvider);
    final controller = ref.read(exploreControllerProvider.notifier);
    final competitors = ref.watch(competitorControllerProvider);
    final analysisStatus = ref.watch(
      analysisControllerProvider.select((s) => s.status),
    );
    final locating = state.locationStatus == LocationStatus.locating;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SiteRow(site: state.site, onClear: controller.clearSite),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: locating ? null : controller.useMyLocation,
                icon: locating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(locating ? 'Locating…' : useMyLocation),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                // Picking needs the live map under the center pin.
                onPressed: MapboxConfig.tokenStatus != MapboxTokenStatus.ok
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        ref.read(mapPickModeProvider.notifier).start();
                      },
                icon: const Icon(Icons.pin_drop_outlined, size: 18),
                label: const Text(pickOnMap),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final category = _BusinessTypeField(
              value: state.category,
              onChanged: controller.selectCategory,
            );
            final radius = SearchDistanceField(
              value: state.radius,
              onChanged: controller.selectRadius,
            );
            // Side by side on normal phones; stacked on narrow ones.
            if (constraints.maxWidth < _sideBySideMinWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  category,
                  const SizedBox(height: AppSpacing.sm),
                  radius,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: category),
                const SizedBox(width: AppSpacing.sm),
                Expanded(flex: 2, child: radius),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (competitors.status == CompetitorStatus.idle) ...[
          if (state.canSearch && competitors.clearedNotice != null) ...[
            InfoNote(
              icon: Icons.refresh,
              lines: [competitors.clearedNotice!],
              tone: NoteTone.warning,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          FilledButton.icon(
            onPressed: state.canSearch
                ? () => ref.read(competitorControllerProvider.notifier).search()
                : null,
            icon: const Icon(Icons.travel_explore),
            label: const Text(findLabel),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            state.canSearch
                ? 'Looks for ${state.category.label.toLowerCase()} businesses '
                      'listed on OpenStreetMap within ${state.radius.label} '
                      'around this spot (straight-line distance, not travel '
                      'distance).'
                : needSiteReason,
            textAlign: TextAlign.center,
            style: mutedSmall(context),
          ),
          if (state.canSearch && state.category.coverageNote != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.category.coverageNote!,
              textAlign: TextAlign.center,
              style: mutedSmall(context),
            ),
          ],
        ] else ...[
          const CompetitorSummary(compact: true),
          if (competitors.result != null) ...[
            const SizedBox(height: AppSpacing.sm),
            // The label says what the tap really does: start the score,
            // or open the one already running / ready.
            FilledButton.icon(
              onPressed: () {
                if (analysisStatus == AnalysisStatus.idle) {
                  ref.read(analysisControllerProvider.notifier).analyze();
                }
                context.go(AppRoutes.analyze);
              },
              icon: const Icon(Icons.insights),
              label: Text(switch (analysisStatus) {
                AnalysisStatus.idle => openAnalyze,
                AnalysisStatus.loading => viewProgress,
                AnalysisStatus.ready => viewScore,
              }),
            ),
            if (analysisStatus == AnalysisStatus.idle) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Next step: checks helpful places and roads nearby, then '
                'shows the score on the ANALYZE tab.',
                textAlign: TextAlign.center,
                style: mutedSmall(context),
              ),
            ],
          ],
        ],
      ],
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.site, required this.onClear});

  final SelectedSite? site;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final site = this.site;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: site != null
                ? context.palette.brand
                : context.palette.accentWash,
            shape: BoxShape.circle,
            border: site != null
                ? null
                : Border.all(color: context.palette.accentContainer),
          ),
          child: Icon(
            site == null
                ? Icons.add_location_alt_outlined
                : site.source.isGps
                ? Icons.my_location
                : Icons.place,
            color: site != null
                ? context.palette.onBrandFill
                : context.palette.brand,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: site == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MapSetupCard.noSiteTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(MapSetupCard.noSiteHint, style: mutedSmall(context)),
                  ],
                )
              : SitePlaceLabel(
                  site: site,
                  maxLines: 1,
                  titleStyle: theme.textTheme.titleMedium,
                ),
        ),
        if (site != null)
          IconButton(
            tooltip: 'Clear location',
            icon: const Icon(Icons.close),
            color: context.palette.textSecondary,
            onPressed: onClear,
          ),
      ],
    );
  }
}

/// The chosen business type as a field that opens the searchable picker.
class _BusinessTypeField extends StatelessWidget {
  const _BusinessTypeField({required this.value, required this.onChanged});

  final BusinessCategory value;
  final ValueChanged<BusinessCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${MapSetupCard.businessTypeLabel}: ${value.label}. '
          'Tap to change.',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () async {
          FocusScope.of(context).unfocus();
          final chosen = await showBusinessTypePicker(context, current: value);
          if (chosen != null) onChanged(chosen);
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: MapSetupCard.businessTypeLabel,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(12, 10, 8, 10),
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              CategoryArt(category: value, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  value.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Icon(Icons.search, color: context.palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/config/mapbox_config.dart';
import '../../../../core/models/business_category.dart';
import '../../../../core/models/search_radius.dart';
import '../../../../core/models/selected_site.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../discovery/presentation/competitor_summary.dart';
import '../../../discovery/state/competitor_controller.dart';
import '../../../places/presentation/site_place_label.dart';
import '../../state/explore_controller.dart';

/// The map tab's compact controls, in the order a first-time user needs
/// them: where (location), what (business type), how far (radius), then
/// "Find nearby competitors" and, once found, the way to the score.
class MapSetupCard extends ConsumerWidget {
  const MapSetupCard({super.key});

  static const findLabel = 'Find nearby competitors';
  static const noSiteTitle = 'Choose a location';
  static const noSiteHint =
      'Search above, use your location, or pick a spot on the map.';
  static const needSiteReason = 'Choose a location first to enable the search.';
  static const useMyLocation = 'Use my location';
  static const pickOnMap = 'Pick on map';
  static const openAnalyze = 'See the score in ANALYZE';

  /// Below this content width the radius buttons move under the business
  /// type instead of squeezing it.
  static const _sideBySideMinWidth = 340.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exploreControllerProvider);
    final controller = ref.read(exploreControllerProvider.notifier);
    final competitors = ref.watch(competitorControllerProvider);
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
            final category = _CategoryMenu(
              value: state.category,
              onChanged: controller.selectCategory,
            );
            final radius = SegmentedButton<SearchRadius>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              segments: [
                for (final radius in SearchRadius.values)
                  ButtonSegment(
                    value: radius,
                    label: Text(radius.label),
                    tooltip: 'Search within ${radius.label}',
                  ),
              ],
              selected: {state.radius},
              onSelectionChanged: (s) => controller.selectRadius(s.single),
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
                Expanded(child: category),
                const SizedBox(width: AppSpacing.sm),
                radius,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (competitors.status == CompetitorStatus.idle) ...[
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
                ? 'Looks up mapped ${state.category.label} records within '
                      '${state.radius.label} on OpenStreetMap.'
                : needSiteReason,
            textAlign: TextAlign.center,
            style: mutedSmall(context),
          ),
        ] else ...[
          const CompetitorSummary(compact: true),
          if (competitors.result != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.analyze),
              icon: const Icon(Icons.insights),
              label: const Text(openAnalyze),
            ),
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
            color: site != null ? BrandColors.emerald700 : BrandColors.mintWash,
            shape: BoxShape.circle,
            border: site != null
                ? null
                : Border.all(color: BrandColors.mintSoft),
          ),
          child: Icon(
            site == null
                ? Icons.add_location_alt_outlined
                : site.source.isGps
                ? Icons.my_location
                : Icons.place,
            color: site != null ? BrandColors.mint : BrandColors.emerald700,
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
            color: BrandColors.inkMuted,
            onPressed: onClear,
          ),
      ],
    );
  }
}

/// Business type as a labeled dropdown: one row instead of five chips.
class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu({required this.value, required this.onChanged});

  final BusinessCategory value;
  final ValueChanged<BusinessCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Business type',
        isDense: true,
        contentPadding: EdgeInsets.fromLTRB(12, 8, 4, 8),
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BusinessCategory>(
          value: value,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          items: [
            for (final category in BusinessCategory.all)
              DropdownMenuItem(
                value: category,
                child: Row(
                  children: [
                    Icon(
                      category.icon,
                      size: 18,
                      color: BrandColors.emerald700,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        category.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (category) {
            if (category != null) onChanged(category);
          },
        ),
      ),
    );
  }
}

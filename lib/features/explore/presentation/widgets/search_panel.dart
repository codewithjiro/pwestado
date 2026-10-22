import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/models/business_category.dart';
import '../../../../core/models/search_radius.dart';
import '../../../../core/models/selected_site.dart';
import '../../state/explore_controller.dart';

/// Search controls: business type, radius, chosen site, and the search action.
class SearchPanel extends ConsumerWidget {
  const SearchPanel({
    super.key,
    this.scrollController,
    this.showDragHandle = false,
  });

  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exploreControllerProvider);
    final controller = ref.read(exploreControllerProvider.notifier);
    final theme = Theme.of(context);

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        showDragHandle ? 0 : AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (showDragHandle) const _DragHandle(),
        Text('Plan a site', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Choose what you want to open and how far to look around it.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: BrandColors.inkMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SectionLabel('Business type'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final category in BusinessCategory.all)
              ChoiceChip(
                avatar: Icon(category.icon, size: 18),
                label: Text(category.label),
                selected: category == state.category,
                showCheckmark: false,
                onSelected: (_) => controller.selectCategory(category),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _Caption(
          'Matches OpenStreetMap tag ${state.category.osmTag}. '
          'Mapped listings can be incomplete.',
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SectionLabel('Search radius'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<SearchRadius>(
            showSelectedIcon: false,
            segments: [
              for (final radius in SearchRadius.values)
                ButtonSegment(value: radius, label: Text(radius.label)),
            ],
            selected: {state.radius},
            onSelectionChanged: (selection) =>
                controller.selectRadius(selection.single),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SectionLabel('Site'),
        _SiteSummary(site: state.site, onClear: controller.clearSite),
        const SizedBox(height: AppSpacing.xl),
        // The Overpass search is wired up in Phase 03 (enabled when
        // state.canSearch). Until then the action stays disabled.
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.travel_explore),
          label: const Text('Find competitors'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Caption(
          state.canSearch
              ? 'Competitor search is not connected yet (next build phase).'
              : 'Choose a site on the map to enable the search.',
          centered: true,
        ),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: BrandColors.outline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: BrandColors.emerald700,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: BrandColors.inkMuted),
    );
  }
}

class _SiteSummary extends StatelessWidget {
  const _SiteSummary({required this.site, required this.onClear});

  final SelectedSite? site;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final site = this.site;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: BrandColors.inkMuted,
    );
    final accuracy = site?.accuracyMeters;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: site != null ? BrandColors.mintSoft : BrandColors.offWhite,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: BrandColors.outline),
      ),
      child: Row(
        children: [
          Icon(
            site == null
                ? Icons.add_location_alt_outlined
                : site.source.isGps
                ? Icons.my_location
                : Icons.place,
            color: BrandColors.emerald700,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  site?.displayLabel ?? 'No site selected',
                  style: theme.textTheme.titleSmall,
                ),
                if (site == null)
                  Text(
                    'Long-press the map to drop a site pin, or tap the '
                    'location button to use where you are.',
                    style: muted,
                  )
                else ...[
                  Text(site.coordinatesLabel, style: muted),
                  if (accuracy != null)
                    Text(
                      'GPS accuracy about ±${accuracy.round()} m',
                      style: muted,
                    ),
                ],
              ],
            ),
          ),
          if (site != null)
            IconButton(
              tooltip: 'Clear site',
              icon: const Icon(Icons.close),
              color: BrandColors.inkMuted,
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

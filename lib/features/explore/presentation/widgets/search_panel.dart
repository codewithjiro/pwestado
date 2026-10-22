import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/models/business_category.dart';
import '../../../../core/models/search_radius.dart';
import '../../../../core/models/selected_site.dart';
import '../../../../shared/widgets/surfaces.dart';
import '../../../analysis/presentation/site_analysis_section.dart';
import '../../../comparison/presentation/comparison_section.dart';
import '../../../discovery/presentation/competitor_results.dart';
import '../../../discovery/state/competitor_controller.dart';
import '../../state/explore_controller.dart';

/// Search controls (business type, radius, chosen site, search action)
/// followed by the score, comparison and results sections. Once results
/// exist, a row of jump chips scrolls straight to each section.
class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({
    super.key,
    this.scrollController,
    this.showDragHandle = false,
  });

  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

enum _Section {
  setup('Setup', Icons.tune_rounded),
  score('Score', Icons.insights_outlined),
  compare('Compare', Icons.compare_arrows_rounded),
  results('Nearby', Icons.storefront_outlined);

  const _Section(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final _keys = {for (final s in _Section.values) s: GlobalKey()};

  void _jumpTo(_Section section) {
    final context = _keys[section]!.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exploreControllerProvider);
    final controller = ref.read(exploreControllerProvider.notifier);
    final searchStatus = ref.watch(
      competitorControllerProvider.select((s) => s.status),
    );
    final searching = searchStatus == CompetitorStatus.loading;
    final hasOutcome = searchStatus != CompetitorStatus.idle && !searching;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        widget.showDragHandle ? 0 : AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showDragHandle) const _DragHandle(),
          if (hasOutcome) ...[
            _SectionNav(onJump: _jumpTo),
            const SizedBox(height: AppSpacing.lg),
          ],
          KeyedSubtree(
            key: _keys[_Section.setup],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Plan a site', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Choose what you want to open and how far to look around '
                  'it.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: BrandColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const EyebrowLabel('Business type', step: 1),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final category in BusinessCategory.all)
                      _CategoryChip(
                        category: category,
                        selected: category == state.category,
                        onSelected: () => controller.selectCategory(category),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _Caption(
                  'Matches OpenStreetMap tag ${state.category.osmTag}. '
                  'Mapped listings can be incomplete.',
                ),
                const SizedBox(height: AppSpacing.xl),
                const EyebrowLabel('Search radius', step: 2),
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
                const EyebrowLabel('Site', step: 3),
                _SiteSummary(site: state.site, onClear: controller.clearSite),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: state.canSearch && !searching
                      ? () => ref
                            .read(competitorControllerProvider.notifier)
                            .search()
                      : null,
                  icon: searching
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.travel_explore),
                  label: Text(searching ? 'Searching…' : 'Find competitors'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Caption(
                  state.canSearch
                      ? 'Searches OpenStreetMap for ${state.category.label} '
                            'records within ${state.radius.label}, only when '
                            'you tap.'
                      : 'Choose a site on the map to enable the search.',
                  centered: true,
                ),
              ],
            ),
          ),
          KeyedSubtree(
            key: _keys[_Section.score],
            child: const SiteAnalysisSection(),
          ),
          KeyedSubtree(
            key: _keys[_Section.compare],
            child: const ComparisonSection(),
          ),
          KeyedSubtree(
            key: _keys[_Section.results],
            child: const CompetitorResults(),
          ),
        ],
      ),
    );
  }
}

/// Jump chips: Setup · Score · Compare · Nearby.
class _SectionNav extends StatelessWidget {
  const _SectionNav({required this.onJump});

  final ValueChanged<_Section> onJump;

  @override
  Widget build(BuildContext context) {
    // A Wrap, not a horizontal scroller: one scrollable per panel keeps
    // drag gestures unambiguous inside the bottom sheet.
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final section in _Section.values)
          ActionChip(
            avatar: Icon(section.icon, size: 18, color: BrandColors.emerald700),
            label: Text(section.label),
            tooltip: 'Jump to ${section.label}',
            backgroundColor: BrandColors.mintWash,
            side: const BorderSide(color: BrandColors.mintSoft),
            onPressed: () => onJump(section),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final BusinessCategory category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : BrandColors.ink;
    return ChoiceChip(
      avatar: Icon(
        category.icon,
        size: 18,
        color: selected ? BrandColors.mint : BrandColors.emerald700,
      ),
      label: Text(category.label),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: foreground),
      selected: selected,
      showCheckmark: false,
      selectedColor: BrandColors.emerald700,
      side: BorderSide(
        color: selected ? BrandColors.emerald700 : BrandColors.outline,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: BrandColors.outline,
          borderRadius: BorderRadius.circular(3),
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
      style: mutedSmall(context),
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
    final muted = mutedSmall(context);
    final accuracy = site?.accuracyMeters;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: site != null ? BrandColors.mintWash : BrandColors.offWhite,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: site != null ? BrandColors.mint : BrandColors.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: site != null
                  ? BrandColors.emerald700
                  : BrandColors.surfaceRaised,
              shape: BoxShape.circle,
              border: site != null
                  ? null
                  : Border.all(color: BrandColors.outline),
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
                  Text(
                    site.coordinatesLabel,
                    style: muted?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
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

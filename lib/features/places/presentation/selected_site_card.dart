import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/models/selected_site.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../explore/state/explore_controller.dart';
import 'site_place_label.dart';

/// The map's chosen site as a card for the ANALYZE and COMPARE tabs: place
/// name, the current business type and radius, and collapsed coordinates.
class SelectedSiteCard extends ConsumerWidget {
  const SelectedSiteCard({
    super.key,
    required this.site,
    this.title = 'Selected location',
  });

  final SelectedSite site;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final explore = ref.watch(exploreControllerProvider);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: BrandColors.emerald700,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.explore),
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text('Change'),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: AppSpacing.md),
                child: Icon(Icons.place, color: BrandColors.emerald700),
              ),
              Expanded(
                child: SitePlaceLabel(
                  site: site,
                  titleStyle: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _Tag(icon: explore.category.icon, text: explore.category.label),
              _Tag(icon: Icons.radar, text: 'Within ${explore.radius.label}'),
            ],
          ),
          SiteTechnicalDetails(site: site),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: BrandColors.mintWash,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: BrandColors.mintSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: BrandColors.emerald700),
          const SizedBox(width: AppSpacing.xs),
          Text(text, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/tab_page.dart';
import '../../explore/state/explore_controller.dart';
import '../../places/presentation/selected_site_card.dart';
import 'comparison_section.dart';

/// COMPARE tab: the map's current location (the one the next-step button
/// stores), then the first / second location comparison.
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final site = ref.watch(exploreControllerProvider.select((s) => s.site));
    return TabPage(
      title: 'Compare',
      subtitle: 'Put two possible locations side by side',
      children: [
        if (site == null)
          GuidanceCard(
            icon: Icons.add_location_alt_outlined,
            title: 'Start with a location on MAPA',
            message:
                'Choose a spot on MAPA, then come back here and tap '
                '"Use this as the first location". Then do the same with a '
                'second spot.',
            action: FilledButton.icon(
              onPressed: () => context.go(AppRoutes.explore),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Go to MAPA'),
            ),
          )
        else
          SelectedSiteCard(site: site, title: 'Current map location'),
        const SizedBox(height: AppSpacing.xs),
        const ComparisonSection(),
      ],
    );
  }
}

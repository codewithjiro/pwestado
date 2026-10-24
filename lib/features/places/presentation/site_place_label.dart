import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/models/selected_site.dart';
import '../../../shared/widgets/surfaces.dart';
import '../domain/place.dart';
import '../state/place_providers.dart';

/// The readable name of a site: place/address first, how it was chosen
/// second. Coordinates are deliberately not shown here; see
/// [SiteTechnicalDetails].
class SitePlaceLabel extends ConsumerWidget {
  const SitePlaceLabel({
    super.key,
    required this.site,
    this.titleStyle,
    this.maxLines = 2,
  });

  static const loadingTitle = 'Finding address…';
  static const unavailableNote = 'Address lookup failed.';

  final SelectedSite site;
  final TextStyle? titleStyle;
  final int maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final point = pointOf(site);
    final label = ref.watch(placeLabelProvider(point));
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.palette.textSecondary,
    );
    final style = titleStyle ?? theme.textTheme.titleSmall;

    final (String title, String? subtitle, Widget? trailing) = switch (label) {
      AsyncData(:final value) => (
        value.title,
        [
          if (value.subtitle != null) value.subtitle!,
          if (value == PlaceLabel.fallback) 'No address found here',
        ].join(' · '),
        null,
      ),
      AsyncError() => (
        PlaceLabel.fallback.title,
        unavailableNote,
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 40),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => ref.invalidate(placeLabelProvider(point)),
          child: const Text('Retry'),
        ),
      ),
      _ => (loadingTitle, null, null),
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: style,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: muted,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(site.source.label, style: muted),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Just the place title, for tight spaces such as table cells.
class PlaceTitleText extends ConsumerWidget {
  const PlaceTitleText({super.key, required this.site, this.style});

  final SelectedSite site;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref.watch(placeLabelProvider(pointOf(site)));
    return Text(switch (label) {
      AsyncData(:final value) => value.title,
      AsyncError() => PlaceLabel.fallback.title,
      _ => SitePlaceLabel.loadingTitle,
    }, style: style);
  }
}

/// Collapsed by default: exact coordinates (the analysis's source of
/// truth), how the site was chosen, GPS accuracy, and label provenance.
class SiteTechnicalDetails extends StatelessWidget {
  const SiteTechnicalDetails({super.key, required this.site});

  static const title = 'Technical details';

  final SelectedSite site;

  @override
  Widget build(BuildContext context) {
    final muted = mutedSmall(context);
    final accuracy = site.accuracyMeters;
    return Theme(
      // No divider lines from ExpansionTile inside cards.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: Icon(
          Icons.tune,
          size: 18,
          color: context.palette.textSecondary,
        ),
        title: Text(title, style: Theme.of(context).textTheme.labelLarge),
        children: [
          _row(context, 'Latitude', site.latitude.toStringAsFixed(6)),
          _row(context, 'Longitude', site.longitude.toStringAsFixed(6)),
          _row(context, 'Chosen by', site.source.label),
          if (accuracy != null)
            _row(context, 'GPS accuracy', '±${accuracy.round()} m'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Scores and saved analyses use these exact coordinates. Place '
            'names come from Mapbox search, describe the surroundings, '
            'and are not stored.',
            style: muted,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final muted = mutedSmall(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(width: 104, child: Text(label, style: muted)),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/config/mapbox_config.dart';

/// Shown in place of the map when no usable Mapbox token was built in.
/// Explains the fix instead of faking a map.
class MapUnavailable extends StatelessWidget {
  const MapUnavailable({
    super.key,
    required this.status,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  static const title = 'Map unavailable';

  final MapboxTokenStatus status;
  final double topInset;

  /// Map height hidden behind the bottom sheet; the card centers above it.
  final double bottomInset;

  String get _reason => switch (status) {
    MapboxTokenStatus.missing =>
      'This build has no Mapbox access token. Rebuild with a public pk. '
          'token passed via --dart-define=ACCESS_TOKEN=...',
    MapboxTokenStatus.secret =>
      'A secret sk. token was supplied. Secret tokens must never ship in an '
          'app, so it was not used. Rebuild with a public pk. token.',
    MapboxTokenStatus.invalid =>
      'The supplied value is not a Mapbox public token (pk.). Rebuild with '
          'a valid public token.',
    MapboxTokenStatus.malformed =>
      'The built-in Mapbox token starts with "pk." but is incomplete or '
          'damaged, so Mapbox would reject it and the map would stay black. '
          'Copy the full default public token (pk.eyJ…) from your Mapbox '
          'account and rebuild.',
    MapboxTokenStatus.ok => '',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$title. $_reason',
      child: ColoredBox(
        color: const Color(0xFFE9EFEB),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            topInset,
            AppSpacing.xl,
            bottomInset,
          ),
          child: Align(
            alignment: Alignment.center,
            // Scrolls when the sheet leaves little room above it.
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: BrandColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: BrandColors.outline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.map_outlined,
                          size: 36,
                          color: BrandColors.emerald700,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: BrandColors.emerald900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _reason,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: BrandColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Use my location still works to set a site.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: BrandColors.emerald700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

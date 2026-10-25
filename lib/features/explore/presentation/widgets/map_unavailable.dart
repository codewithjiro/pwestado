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

  /// Users only learn that the map is off; the token-specific fix for each
  /// [MapboxTokenStatus] is documented in MapboxConfig, not shown here.
  String get _reason => switch (status) {
    MapboxTokenStatus.ok => '',
    _ => 'The map can’t be shown in this version of the app.',
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
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: context.palette.borderStrong),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 36,
                          color: context.palette.brand,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: context.palette.heading,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _reason,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Use my location still works to set a site.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.palette.brand,
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

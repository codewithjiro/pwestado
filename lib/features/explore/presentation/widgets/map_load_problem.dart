import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Why the live map is not showing. Anything but [none] covers the map
/// with an explanation and Retry, so a failed load is never an endless
/// black rectangle.
enum MapLoadProblem {
  none,

  /// Mapbox refused the token (HTTP 401/403). The black-map release was
  /// built with a malformed token, which fails exactly like this.
  tokenRejected,

  /// The style itself failed for another reason (often no connection).
  styleFailed,

  /// The style loaded but repeated tile/source errors keep the map blank.
  tilesFailed,

  /// Nothing has rendered for a long time and no error was reported.
  slow;

  String get title => switch (this) {
    tokenRejected => 'Mapbox rejected the map token',
    styleFailed => 'The map could not load',
    tilesFailed => 'Map tiles are not loading',
    slow => 'The map is taking too long',
    none => '',
  };

  String get message => switch (this) {
    tokenRejected =>
      'This build\'s Mapbox access token was refused, so no map can be '
          'drawn. Rebuild the app with a valid public token (pk.eyJ…). '
          'Place search and competitor data still need it too.',
    styleFailed =>
      'The map style did not download. Check the internet connection, '
          'then retry.',
    tilesFailed =>
      'The map started but its tiles keep failing to download. Check the '
          'internet connection, then retry.',
    slow =>
      'Nothing has been drawn yet. The connection may be slow or offline. '
          'Retry, or keep waiting; the map appears as soon as it loads.',
    none => '',
  };

  IconData get icon => switch (this) {
    tokenRejected => Icons.key_off_outlined,
    styleFailed || tilesFailed => Icons.cloud_off_outlined,
    slow => Icons.hourglass_bottom,
    none => Icons.map_outlined,
  };
}

/// Classifies a Mapbox load error. [message] must not be shown to users:
/// it can contain request URLs with the token.
MapLoadProblem classifyMapLoadError({
  required bool isStyleError,
  required String message,
  required int tileErrorsBeforeFirstRender,
}) {
  final lower = message.toLowerCase();
  if (lower.contains('401') ||
      lower.contains('403') ||
      lower.contains('unauthorized') ||
      lower.contains('forbidden') ||
      lower.contains('invalid token') ||
      lower.contains('not authorized')) {
    return MapLoadProblem.tokenRejected;
  }
  if (isStyleError) return MapLoadProblem.styleFailed;
  // A few tile misses are normal; many before anything rendered are not.
  if (tileErrorsBeforeFirstRender >= MapLoadWatchdog.tileErrorLimit) {
    return MapLoadProblem.tilesFailed;
  }
  return MapLoadProblem.none;
}

abstract final class MapLoadWatchdog {
  /// No completed first render after this long counts as [slow].
  static const timeout = Duration(seconds: 20);
  static const tileErrorLimit = 4;
}

/// Opaque cover over the native map with the reason and a Retry button.
class MapProblemOverlay extends StatelessWidget {
  const MapProblemOverlay({
    super.key,
    required this.problem,
    required this.onRetry,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final MapLoadProblem problem;
  final VoidCallback onRetry;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${problem.title}. ${problem.message}',
      child: ColoredBox(
        color: const Color(0xFFE9EFEB),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            topInset + AppSpacing.lg,
            AppSpacing.xl,
            bottomInset + AppSpacing.lg,
          ),
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Material(
                  color: context.palette.surface,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          problem.icon,
                          size: 40,
                          color: problem == MapLoadProblem.slow
                              ? context.palette.brand
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          problem.title,
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          problem.message,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
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

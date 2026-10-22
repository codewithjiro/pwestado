import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/models/selected_site.dart';
import '../../data/location_service.dart';
import '../../state/explore_controller.dart';

/// Floating map buttons that ride just above the bottom sheet: show the
/// selected site, return to Santa Ana, and use the device location.
///
/// Also reports GPS outcomes, because a failed location request must never
/// look like nothing happened.
class MapControls extends ConsumerWidget {
  const MapControls({
    super.key,
    required this.bottomInset,
    required this.mapAvailable,
    required this.onRecenterHome,
    required this.onShowSite,
  });

  final ValueListenable<double> bottomInset;
  final bool mapAvailable;
  final VoidCallback onRecenterHome;
  final ValueChanged<SelectedSite> onShowSite;

  /// Hide the buttons once the sheet covers most of the screen.
  static const _hideAboveFraction = 0.66;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(exploreControllerProvider.select((s) => s.locationStatus), (
      prev,
      next,
    ) {
      if (prev != next) _reportLocationStatus(context, ref, next);
    });

    final site = ref.watch(exploreControllerProvider.select((s) => s.site));
    final locating = ref.watch(
      exploreControllerProvider.select(
        (s) => s.locationStatus == LocationStatus.locating,
      ),
    );

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) => ValueListenableBuilder<double>(
          valueListenable: bottomInset,
          builder: (context, inset, child) {
            final hidden = inset > constraints.maxHeight * _hideAboveFraction;
            return Padding(
              padding: EdgeInsets.only(
                right: AppSpacing.lg,
                bottom: inset + AppSpacing.lg,
              ),
              child: Align(
                alignment: Alignment.bottomRight,
                child: IgnorePointer(
                  ignoring: hidden,
                  child: AnimatedOpacity(
                    opacity: hidden ? 0 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mapAvailable && site != null) ...[
                _MapButton(
                  tooltip: 'Show selected site',
                  icon: Icons.place,
                  onPressed: () => onShowSite(site),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (mapAvailable) ...[
                _MapButton(
                  tooltip: 'Back to Santa Ana',
                  icon: Icons.home_outlined,
                  onPressed: onRecenterHome,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              _MapButton(
                tooltip: 'Use my location',
                icon: Icons.my_location,
                primary: true,
                busy: locating,
                onPressed: () => ref
                    .read(exploreControllerProvider.notifier)
                    .useMyLocation(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reportLocationStatus(
    BuildContext context,
    WidgetRef ref,
    LocationStatus status,
  ) {
    final service = ref.read(locationServiceProvider);
    final (String message, SnackBarAction? action) = switch (status) {
      LocationStatus.located => ('Site set to your current location.', null),
      LocationStatus.denied => (
        'Location permission denied. You can still long-press the map to '
            'choose a site.',
        null,
      ),
      LocationStatus.deniedForever => (
        'Location is blocked for PWESTADO. Allow it in app settings, or '
            'long-press the map to choose a site.',
        SnackBarAction(label: 'Settings', onPressed: service.openAppSettings),
      ),
      LocationStatus.serviceDisabled => (
        'Device location is turned off. Turn it on, or long-press the map '
            'to choose a site.',
        SnackBarAction(
          label: 'Turn on',
          onPressed: service.openLocationSettings,
        ),
      ),
      LocationStatus.unavailable => (
        'Could not get a GPS fix. Try again, or long-press the map to '
            'choose a site.',
        null,
      ),
      LocationStatus.idle || LocationStatus.locating => ('', null),
    };
    if (message.isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: action == null ? 4 : 8),
        ),
      );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.busy = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : BrandColors.emerald700;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: primary ? BrandColors.emerald700 : BrandColors.surfaceRaised,
        elevation: 3,
        shadowColor: const Color(0x550B3D2E),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: SizedBox.square(
            dimension: 52,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: foreground,
                        semanticsLabel: 'Finding your location',
                      ),
                    )
                  : Icon(icon, color: foreground, semanticLabel: tooltip),
            ),
          ),
        ),
      ),
    );
  }
}

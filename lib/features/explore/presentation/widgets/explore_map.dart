import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../app/theme.dart';
import '../../../../core/config/mapbox_config.dart';
import '../../../../core/models/selected_site.dart';
import '../../data/location_service.dart';
import '../../state/explore_controller.dart';
import 'map_controls.dart';
import 'map_unavailable.dart';
import 'site_pin_image.dart';

/// Live Mapbox Standard map with long-press site picking, the selected-site
/// pin, the device location puck, and floating camera controls.
///
/// Only listens to the selected site and GPS status, so changing category or
/// radius never rebuilds or reinitializes the native map view.
class ExploreMap extends ConsumerStatefulWidget {
  const ExploreMap({
    super.key,
    required this.topInset,
    required this.bottomInset,
    this.tokenStatus,
  });

  /// Height covered by floating UI at the top (brand header). Mapbox's logo,
  /// attribution and compass are placed just below it so they stay visible.
  final double topInset;

  /// Height covered by the bottom sheet, in logical pixels. Used to keep
  /// camera targets and floating buttons in the visible part of the map.
  final ValueListenable<double> bottomInset;

  /// Overrides [MapboxConfig.tokenStatus]; for tests.
  final MapboxTokenStatus? tokenStatus;

  @override
  ConsumerState<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends ConsumerState<ExploreMap> {
  /// The SDK re-applies the viewport whenever this object changes, which
  /// would snap the camera back, so keep a single instance.
  static final _initialViewport = CameraViewportState(
    center: Point(
      coordinates: Position(MapDefaults.longitude, MapDefaults.latitude),
    ),
    zoom: MapDefaults.zoom,
  );

  /// Built once and reused. Handing Flutter the same instance means the SDK
  /// never sees a widget update; in 3.33.0 an update that arrives before the
  /// native map exists drops the initial viewport (map opens on the globe).
  late final Widget _mapWidget = MapWidget(
    key: const ValueKey('pwestado-map'),
    styleUri: MapboxStyles.STANDARD,
    viewport: _initialViewport,
    onMapCreated: _onMapCreated,
    onStyleLoadedListener: _onStyleLoaded,
    onMapLoadErrorListener: _onMapLoadError,
  );

  MapboxMap? _map;
  PointAnnotationManager? _pinManager;
  PointAnnotation? _sitePin;
  Uint8List? _pinImage;
  Future<void> _pinSync = Future.value();
  bool _styleLoaded = false;
  bool _styleFailed = false;

  MapboxTokenStatus get _tokenStatus =>
      widget.tokenStatus ?? MapboxConfig.tokenStatus;

  @override
  void didUpdateWidget(ExploreMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topInset != widget.topInset) _placeOrnaments();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    map.addInteraction(LongTapInteraction.onMap(_onLongTap));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await _placeOrnaments();
    if (await ref.read(locationServiceProvider).hasPermission()) {
      await _showLocationPuck();
    }
  }

  Future<void> _placeOrnaments() async {
    final map = _map;
    if (map == null) return;
    final top = widget.topInset + AppSpacing.sm;
    await map.logo.updateSettings(
      LogoSettings(
        position: OrnamentPosition.TOP_LEFT,
        marginLeft: AppSpacing.lg,
        marginTop: top,
      ),
    );
    await map.attribution.updateSettings(
      AttributionSettings(
        position: OrnamentPosition.TOP_LEFT,
        // Sits to the right of the ~85 dp wide Mapbox wordmark.
        marginLeft: AppSpacing.lg + 92,
        marginTop: top - 4,
        iconColor: BrandColors.emerald700.toARGB32(),
      ),
    );
    await map.compass.updateSettings(
      CompassSettings(
        position: OrnamentPosition.TOP_RIGHT,
        marginRight: AppSpacing.lg,
        marginTop: top,
      ),
    );
  }

  void _onStyleLoaded(StyleLoadedEventData _) {
    _styleLoaded = true;
    if (_styleFailed && mounted) setState(() => _styleFailed = false);
    _queuePinSync();
  }

  void _onMapLoadError(MapLoadingErrorEventData event) {
    // The raw SDK message can contain request URLs with the access token, so
    // it is never shown or logged. Only style failures blank the whole map;
    // individual tile errors are left to the SDK's own retry.
    if (event.type == MapLoadErrorType.STYLE && mounted) {
      setState(() => _styleFailed = true);
    }
  }

  void _retryStyle() {
    setState(() => _styleFailed = false);
    _map?.setStyleURI(MapboxStyles.STANDARD);
  }

  void _onLongTap(MapContentGestureContext context) {
    final coordinates = context.point.coordinates;
    ref
        .read(exploreControllerProvider.notifier)
        .selectSite(
          latitude: coordinates.lat.toDouble(),
          longitude: coordinates.lng.toDouble(),
        );
  }

  /// Serializes pin updates so rapid long presses cannot interleave native
  /// calls. Each run reads the latest site, so the final state always wins.
  void _queuePinSync() {
    _pinSync = _pinSync.then((_) => _syncPin()).catchError((Object e) {
      debugPrint('Site pin update failed: $e');
    });
  }

  Future<void> _syncPin() async {
    final map = _map;
    if (map == null || !_styleLoaded || !mounted) return;
    final site = ref.read(exploreControllerProvider).site;

    if (site == null) {
      if (_sitePin != null) {
        await _pinManager?.deleteAll();
        _sitePin = null;
      }
      return;
    }

    final point = Point(coordinates: Position(site.longitude, site.latitude));
    final existing = _sitePin;
    if (existing != null) {
      existing.geometry = point;
      await _pinManager!.update(existing);
      return;
    }

    _pinManager ??= await map.annotations.createPointAnnotationManager(
      id: 'pwestado-selected-site',
    );
    _pinImage ??= await renderSitePinPng();
    _sitePin = await _pinManager!.create(
      PointAnnotationOptions(
        geometry: point,
        image: _pinImage,
        // The pin's tip is the image's bottom edge: anchor there so the tip
        // marks the exact coordinate at every zoom level.
        iconAnchor: IconAnchor.BOTTOM,
      ),
    );
  }

  Future<void> _showLocationPuck() async {
    await _map?.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: BrandColors.emerald500.toARGB32(),
        showAccuracyRing: true,
        accuracyRingColor: BrandColors.mint.withValues(alpha: 0.25).toARGB32(),
        accuracyRingBorderColor: BrandColors.emerald500.toARGB32(),
      ),
    );
  }

  MbxEdgeInsets get _cameraPadding => MbxEdgeInsets(
    top: widget.topInset,
    left: 0,
    bottom: widget.bottomInset.value,
    right: 0,
  );

  Future<void> _flyTo(double latitude, double longitude, double zoom) async {
    await _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: zoom,
        padding: _cameraPadding,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  void _flyToSite(SelectedSite site) =>
      _flyTo(site.latitude, site.longitude, MapDefaults.siteZoom);

  void _flyHome() =>
      _flyTo(MapDefaults.latitude, MapDefaults.longitude, MapDefaults.zoom);

  @override
  Widget build(BuildContext context) {
    ref.listen(exploreControllerProvider.select((s) => s.site), (prev, next) {
      _queuePinSync();
      // Bring GPS fixes into view; a long-pressed site is already on screen.
      if (next != null && next.source.isGps && next != prev) _flyToSite(next);
    });
    ref.listen(exploreControllerProvider.select((s) => s.locationStatus), (
      prev,
      next,
    ) {
      if (next == LocationStatus.located) _showLocationPuck();
    });

    final hasToken = _tokenStatus == MapboxTokenStatus.ok;

    return Stack(
      children: [
        Positioned.fill(
          child: hasToken
              ? _mapWidget
              : ValueListenableBuilder<double>(
                  valueListenable: widget.bottomInset,
                  builder: (context, bottom, _) => MapUnavailable(
                    status: _tokenStatus,
                    topInset: widget.topInset,
                    bottomInset: bottom,
                  ),
                ),
        ),
        if (hasToken && _styleFailed)
          Positioned(
            top: widget.topInset + AppSpacing.xxl + AppSpacing.sm,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: _MapErrorBanner(onRetry: _retryStyle),
          ),
        MapControls(
          bottomInset: widget.bottomInset,
          mapAvailable: hasToken,
          onRecenterHome: _flyHome,
          onShowSite: _flyToSite,
        ),
      ],
    );
  }
}

class _MapErrorBanner extends StatelessWidget {
  const _MapErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: BrandColors.surfaceRaised,
      elevation: 3,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'The map could not load. Check the internet connection and '
                'that the Mapbox token is valid.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

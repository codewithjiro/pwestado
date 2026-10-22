import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../app/theme.dart';
import '../../../../core/config/mapbox_config.dart';
import '../../../../core/models/selected_site.dart';
import '../../../../core/utils/geo.dart';
import '../../../../core/utils/redact.dart';
import '../../../discovery/domain/competitors.dart';
import '../../../discovery/presentation/competitor_results.dart';
import '../../../discovery/presentation/source_labels.dart';
import '../../../discovery/state/competitor_controller.dart';
import '../../data/location_service.dart';
import '../../state/explore_controller.dart';
import 'competitor_pin_image.dart';
import 'map_controls.dart';
import 'map_unavailable.dart';
import 'site_pin_image.dart';

/// Live Mapbox Standard map with long-press site picking, the selected-site
/// pin, competitor markers with the searched radius, the device location
/// puck, and floating camera controls.
///
/// Only listens to the selected site, GPS status, and competitor results,
/// so changing category or radius never rebuilds or reinitializes the
/// native map view.
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

  static const _selectedCompetitorSize = 1.4;

  MapboxMap? _map;
  PolygonAnnotationManager? _radiusManager;
  PointAnnotationManager? _competitorManager;
  PointAnnotationManager? _pinManager;
  Cancelable? _competitorTaps;
  PointAnnotation? _sitePin;
  Uint8List? _pinImage;
  Uint8List? _competitorImage;

  /// What is currently drawn, so each sync only touches what changed.
  CompetitorResult? _drawnResult;
  CompetitorQuery? _drawnRadius;
  String? _drawnSelection;
  final _competitorPins = <String, PointAnnotation>{};
  final _annotationToBusiness = <String, String>{};

  Future<void> _mapSync = Future.value();
  bool _styleLoaded = false;
  bool _styleFailed = false;

  MapboxTokenStatus get _tokenStatus =>
      widget.tokenStatus ?? MapboxConfig.tokenStatus;

  @override
  void didUpdateWidget(ExploreMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topInset != widget.topInset) _placeOrnaments();
  }

  @override
  void dispose() {
    _competitorTaps?.cancel();
    super.dispose();
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
    _queueMapSync();
  }

  void _onMapLoadError(MapLoadingErrorEventData event) {
    // The raw SDK message can contain request URLs with the access token, so
    // it is never shown, and only logged (debug builds) after redaction.
    if (kDebugMode) {
      debugPrint(
        'Mapbox ${event.type.name} load error'
        '${event.sourceId == null ? '' : ' (source ${event.sourceId})'}: '
        '${redactSecrets(event.message)}',
      );
    }
    // Only style failures blank the whole map; individual tile errors are
    // left to the SDK's own retry.
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

  void _onCompetitorTap(PointAnnotation annotation) {
    final key = _annotationToBusiness[annotation.id];
    if (key == null || !mounted) return;
    final businesses = ref.read(competitorControllerProvider).businesses;
    for (final business in businesses) {
      if (business.key == key) {
        openCompetitorDetails(context, ref, business);
        return;
      }
    }
  }

  /// Serializes annotation updates so rapid changes cannot interleave
  /// native calls. Each run reads the latest state, so the final state
  /// always wins.
  void _queueMapSync() {
    _mapSync = _mapSync
        .then((_) async {
          await _syncSitePin();
          await _syncCompetitors();
        })
        .catchError((Object e) {
          debugPrint('Map annotation update failed: ${describeError(e)}');
        });
  }

  /// Creates the annotation layers once. Creation order is drawing order:
  /// the radius ring at the bottom, competitors above it, the site pin on
  /// top so it is never hidden by a nearby competitor.
  Future<bool> _ensureManagers() async {
    final map = _map;
    if (map == null || !_styleLoaded || !mounted) return false;
    if (_pinManager != null) return true;

    final annotations = map.annotations;
    _radiusManager = await annotations.createPolygonAnnotationManager(
      id: 'pwestado-search-radius',
    );
    final competitors = await annotations.createPointAnnotationManager(
      id: 'pwestado-competitors',
    );
    // Every record must stay visible: never let Mapbox's collision
    // detection hide a marker because it overlaps another one.
    await competitors.setIconAllowOverlap(true);
    await competitors.setIconIgnorePlacement(true);
    _competitorTaps = competitors.tapEvents(onTap: _onCompetitorTap);
    _competitorManager = competitors;

    final site = await annotations.createPointAnnotationManager(
      id: 'pwestado-selected-site',
    );
    await site.setIconAllowOverlap(true);
    _pinManager = site;
    return true;
  }

  Future<void> _syncSitePin() async {
    if (!await _ensureManagers()) return;
    final site = ref.read(exploreControllerProvider).site;

    if (site == null) {
      if (_sitePin != null) {
        await _pinManager!.deleteAll();
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

  /// Mirrors the competitor search state: markers for exactly the records
  /// in the current result (none otherwise), the searched radius, and the
  /// highlighted record.
  Future<void> _syncCompetitors() async {
    if (!await _ensureManagers()) return;
    final state = ref.read(competitorControllerProvider);
    final result = state.result;

    if (!identical(result, _drawnResult)) {
      await _competitorManager!.deleteAll();
      _competitorPins.clear();
      _annotationToBusiness.clear();
      _drawnSelection = null;
      _drawnResult = null;

      final businesses = result?.businesses ?? const <NearbyBusiness>[];
      if (businesses.isNotEmpty) {
        _competitorImage ??= await renderCompetitorPinPng();
        final created = await _competitorManager!.createMulti([
          for (final business in businesses)
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(business.longitude, business.latitude),
              ),
              image: _competitorImage,
              iconAnchor: IconAnchor.CENTER,
            ),
        ]);
        for (final (index, annotation) in created.indexed) {
          if (annotation == null) continue;
          final key = businesses[index].key;
          _competitorPins[key] = annotation;
          _annotationToBusiness[annotation.id] = key;
        }
      }
      _drawnResult = result;
    }

    final selected = state.selectedKey;
    if (selected != _drawnSelection) {
      for (final key in {_drawnSelection, selected}) {
        final annotation = _competitorPins[key];
        if (annotation == null) continue;
        annotation
          ..iconSize = key == selected ? _selectedCompetitorSize : 1
          ..symbolSortKey = key == selected ? 1 : 0;
        await _competitorManager!.update(annotation);
      }
      _drawnSelection = selected;
    }

    final radiusQuery = result?.query;
    if (radiusQuery != _drawnRadius) {
      await _radiusManager!.deleteAll();
      _drawnRadius = null;
      if (radiusQuery != null) {
        await _radiusManager!.create(
          PolygonAnnotationOptions(
            geometry: _circle(radiusQuery),
            fillColor: BrandColors.emerald500.toARGB32(),
            fillOpacity: 0.08,
            fillOutlineColor: BrandColors.emerald700.toARGB32(),
          ),
        );
      }
      _drawnRadius = radiusQuery;
    }
  }

  /// The searched area as a 72-sided polygon.
  static Polygon _circle(CompetitorQuery query) {
    final ring = [
      for (var i = 0; i <= 72; i++)
        () {
          final (lat, lon) = destinationPoint(
            query.latitude,
            query.longitude,
            i * 5.0,
            query.radius.meters.toDouble(),
          );
          return Position(lon, lat);
        }(),
    ];
    return Polygon(coordinates: [ring]);
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

  /// Map height reserved for the bottom sheet when framing the camera. Capped
  /// at the sheet's resting height: when the sheet is pulled up (e.g. to
  /// read results) the camera still frames the area that will be visible
  /// once it is lowered, instead of squeezing everything into a sliver.
  double get _cameraBottomInset {
    final height = context.size?.height ?? 0;
    return math.min(widget.bottomInset.value, height * _maxCameraBottomShare);
  }

  static const _maxCameraBottomShare = 0.55;

  MbxEdgeInsets get _cameraPadding => MbxEdgeInsets(
    top: widget.topInset,
    left: 0,
    bottom: _cameraBottomInset,
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

  /// Zooms so the whole searched circle fits in the visible part of the map.
  void _fitSearchArea(CompetitorQuery query) {
    final size = context.size;
    if (size == null) return;
    final visibleHeight = size.height - widget.topInset - _cameraBottomInset;
    final pixels = math.max(120.0, math.min(size.width, visibleHeight)) * 0.85;
    // Mapbox uses 512 px tiles: 78271.517 m per px at zoom 0 on the equator.
    final metersPerPixelAtZoom0 =
        78271.517 * math.cos(query.latitude * math.pi / 180);
    final zoom =
        math.log(metersPerPixelAtZoom0 * pixels / (2 * query.radius.meters)) /
        math.ln2;
    _flyTo(query.latitude, query.longitude, zoom.clamp(11.0, 17.0));
  }

  Future<void> _easeToBusiness(NearbyBusiness business) async {
    await _map?.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(business.longitude, business.latitude),
        ),
        padding: _cameraPadding,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(exploreControllerProvider.select((s) => s.site), (prev, next) {
      _queueMapSync();
      // Bring GPS fixes into view; a long-pressed site is already on screen.
      if (next != null && next.source.isGps && next != prev) _flyToSite(next);
    });
    ref.listen(exploreControllerProvider.select((s) => s.locationStatus), (
      prev,
      next,
    ) {
      if (next == LocationStatus.located) _showLocationPuck();
    });
    ref.listen(competitorControllerProvider, (prev, next) {
      _queueMapSync();
      final result = next.result;
      if (result != null && !identical(result, prev?.result)) {
        _fitSearchArea(result.query);
      }
      final selected = next.selected;
      if (selected != null && next.selectedKey != prev?.selectedKey) {
        _easeToBusiness(selected);
      }
    });

    final hasToken = _tokenStatus == MapboxTokenStatus.ok;
    final showingSample = ref.watch(
      competitorControllerProvider.select(
        (s) => s.status == CompetitorStatus.sample,
      ),
    );

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
        if (hasToken && showingSample && !_styleFailed)
          Positioned(
            top: widget.topInset + AppSpacing.xxl + AppSpacing.sm,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: const Center(child: _SampleMapChip()),
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

/// Keeps "sample" visible on the map itself, not only in the panel.
class _SampleMapChip extends StatelessWidget {
  const _SampleMapChip();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SampleBanner.background,
      elevation: 3,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.science_outlined,
              size: 16,
              color: SampleBanner.foreground,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${SampleBanner.title} · NOT REAL BUSINESSES',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: SampleBanner.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
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

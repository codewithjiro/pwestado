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
import '../../../comparison/domain/site_comparison.dart';
import '../../../comparison/state/comparison_controller.dart';
import '../../../discovery/domain/competitors.dart';
import '../../../discovery/presentation/competitor_results.dart';
import '../../../discovery/presentation/source_labels.dart';
import '../../../discovery/state/competitor_controller.dart';
import '../../data/location_service.dart';
import '../../state/explore_controller.dart';
import 'compare_pin_image.dart';
import 'competitor_pin_image.dart';
import 'map_controls.dart';
import 'map_load_problem.dart';
import 'map_unavailable.dart';
import 'site_pin_image.dart';

/// Live Mapbox Standard map with long-press and pick-mode site choice, the selected-site
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
    onMapLoadedListener: _onMapLoaded,
    onMapLoadErrorListener: _onMapLoadError,
  );

  static const _selectedCompetitorSize = 1.4;

  MapboxMap? _map;
  PolygonAnnotationManager? _radiusManager;
  PointAnnotationManager? _competitorManager;
  PointAnnotationManager? _pinManager;
  PointAnnotationManager? _compareManager;
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
  final _comparePins = <CompareSlot, PointAnnotation>{};
  final _drawnCompareSites = <CompareSlot, SelectedSite>{};
  final _compareImages = <CompareSlot, Uint8List>{};

  Future<void> _mapSync = Future.value();
  bool _styleLoaded = false;

  /// True once Mapbox reports a fully rendered map. Until then the load
  /// watchdog may cover the (black) native view with an explanation.
  bool _mapLoaded = false;
  int _tileErrors = 0;
  Timer? _watchdog;
  MapLoadProblem _problem = MapLoadProblem.none;

  /// Id of the last site chosen by a gesture on the visible map; other
  /// site changes (GPS, search, saved analyses) move the camera to the site.
  String? _gestureSiteId;

  MapboxTokenStatus get _tokenStatus =>
      widget.tokenStatus ?? MapboxConfig.tokenStatus;

  @override
  void didUpdateWidget(ExploreMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topInset != widget.topInset) _placeOrnaments();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _competitorTaps?.cancel();
    super.dispose();
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(MapLoadWatchdog.timeout, () {
      if (!mounted || _mapLoaded || _problem != MapLoadProblem.none) return;
      debugPrint('Mapbox: no rendered map after ${MapLoadWatchdog.timeout}');
      setState(() => _problem = MapLoadProblem.slow);
    });
  }

  void _setProblem(MapLoadProblem problem) {
    if (!mounted || problem == _problem) return;
    setState(() => _problem = problem);
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _startWatchdog();
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
    if (_problem == MapLoadProblem.styleFailed) {
      _setProblem(MapLoadProblem.none);
    }
    _queueMapSync();
  }

  void _onMapLoaded(MapLoadedEventData _) {
    _mapLoaded = true;
    _watchdog?.cancel();
    debugPrint('Mapbox: map rendered');
    _setProblem(MapLoadProblem.none);
  }

  void _onMapLoadError(MapLoadingErrorEventData event) {
    // The raw SDK message can contain request URLs with the access token, so
    // it is never shown, and is logged only after redaction. Release builds
    // log it too: this is the evidence for diagnosing a blank map.
    debugPrint(
      'Mapbox ${event.type.name} load error'
      '${event.sourceId == null ? '' : ' (source ${event.sourceId})'}: '
      '${redactSecrets(event.message)}',
    );
    final isStyle = event.type == MapLoadErrorType.STYLE;
    if (!isStyle && !_mapLoaded) _tileErrors++;
    final problem = classifyMapLoadError(
      isStyleError: isStyle,
      message: event.message,
      tileErrorsBeforeFirstRender: _tileErrors,
    );
    // Once something rendered, isolated tile errors are left to the SDK's
    // own retry; only a token rejection is worth interrupting for.
    if (problem == MapLoadProblem.none) return;
    if (_mapLoaded && problem != MapLoadProblem.tokenRejected) return;
    _setProblem(problem);
  }

  void _retryLoad() {
    setState(() => _problem = MapLoadProblem.none);
    _mapLoaded = false;
    _tileErrors = 0;
    _startWatchdog();
    _map?.loadStyleURI(MapboxStyles.STANDARD);
  }

  void _onLongTap(MapContentGestureContext context) {
    final coordinates = context.point.coordinates;
    _selectAt(coordinates.lat.toDouble(), coordinates.lng.toDouble());
  }

  void _selectAt(double latitude, double longitude) {
    final controller = ref.read(exploreControllerProvider.notifier);
    controller.selectSite(latitude: latitude, longitude: longitude);
    _gestureSiteId = ref.read(exploreControllerProvider).site?.id;
  }

  /// "Use this spot" in pick mode: the coordinate under the center pin.
  Future<void> _confirmPick() async {
    final map = _map;
    final size = context.size;
    if (map == null || size == null) return;
    final point = await map.coordinateForPixel(
      ScreenCoordinate(x: size.width / 2, y: size.height / 2),
    );
    if (!mounted) return;
    _selectAt(
      point.coordinates.lat.toDouble(),
      point.coordinates.lng.toDouble(),
    );
    ref.read(mapPickModeProvider.notifier).stop();
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
          await _syncComparePins();
          await _syncCompetitors();
        })
        .catchError((Object e) {
          debugPrint('Map annotation update failed: ${describeError(e)}');
        });
  }

  /// Creates the annotation layers once. Creation order is drawing order:
  /// the radius ring at the bottom, competitors above it, then the Site A/B
  /// pins, and the site pin on top so it is never hidden by a nearby
  /// competitor.
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

    final compare = await annotations.createPointAnnotationManager(
      id: 'pwestado-compare-sites',
    );
    await compare.setIconAllowOverlap(true);
    await compare.setIconIgnorePlacement(true);
    _compareManager = compare;

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
    final slots = ref.read(comparisonControllerProvider);
    // A pin stored as Site A/B is drawn with its letter instead; the plain
    // pin on the same spot would hide it.
    final shownAsSlot =
        site != null &&
        (slots.a.site?.id == site.id || slots.b.site?.id == site.id);

    if (site == null || shownAsSlot) {
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

  /// One lettered pin per assigned comparison slot, at that slot's own
  /// stored site (never the current map pin unless it was assigned).
  Future<void> _syncComparePins() async {
    if (!await _ensureManagers()) return;
    final slots = ref.read(comparisonControllerProvider);
    for (final slot in CompareSlot.values) {
      final site = slots[slot].site;
      if (site == _drawnCompareSites[slot]) continue;

      final existing = _comparePins.remove(slot);
      _drawnCompareSites.remove(slot);
      if (existing != null) await _compareManager!.delete(existing);
      if (site == null) continue;

      final image = _compareImages[slot] ??= await renderComparePinPng(slot);
      final pin = await _compareManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(site.longitude, site.latitude)),
          image: image,
          iconAnchor: IconAnchor.BOTTOM,
          symbolSortKey: slot == CompareSlot.a ? 1 : 0,
        ),
      );
      _comparePins[slot] = pin;
      _drawnCompareSites[slot] = site;
    }
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
      // Bring GPS fixes, searched places and reopened saved sites into
      // view; a site picked by a gesture is already on screen.
      if (next != null && next != prev && next.id != _gestureSiteId) {
        _flyToSite(next);
      }
    });
    ref.listen(
      comparisonControllerProvider.select((s) => (s.a.site, s.b.site)),
      (_, _) => _queueMapSync(),
    );
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
    final hasProblem = hasToken && _problem != MapLoadProblem.none;
    final picking = hasToken && ref.watch(mapPickModeProvider);
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
        if (hasProblem)
          Positioned.fill(
            child: ValueListenableBuilder<double>(
              valueListenable: widget.bottomInset,
              builder: (context, bottom, _) => MapProblemOverlay(
                problem: _problem,
                onRetry: _retryLoad,
                topInset: widget.topInset,
                bottomInset: bottom,
              ),
            ),
          ),
        if (hasToken && showingSample && !hasProblem && !picking)
          Positioned(
            top: widget.topInset + AppSpacing.xxl + AppSpacing.sm,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: const Center(child: _SampleMapChip()),
          ),
        if (picking && !hasProblem) ...[
          const Positioned.fill(child: IgnorePointer(child: _CenterPin())),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: _PickBar(
              onCancel: ref.read(mapPickModeProvider.notifier).stop,
              onConfirm: _confirmPick,
            ),
          ),
        ] else
          MapControls(
            bottomInset: widget.bottomInset,
            mapAvailable: hasToken && !hasProblem,
            onRecenterHome: _flyHome,
            onShowSite: _flyToSite,
          ),
      ],
    );
  }
}

/// Fixed pin at the map's center for "Pick on map"; its tip marks the spot.
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  static const size = 52.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: BrandColors.emerald900,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
          // Icons.place draws its tip about 4% above the box's bottom edge.
          Transform.translate(
            offset: const Offset(0, -size / 2 + 2),
            child: const Icon(
              Icons.place,
              size: size,
              color: BrandColors.emerald700,
              shadows: [Shadow(color: Color(0x660B3D2E), blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickBar extends StatelessWidget {
  const _PickBar({required this.onCancel, required this.onConfirm});

  static const confirmLabel = 'Use this spot';

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: BrandColors.surfaceRaised,
      elevation: 6,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pick a spot', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Drag the map until the green pin sits on your spot, then tap '
              '"$confirmLabel". Pinch to zoom in for precision.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check),
                    label: const Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

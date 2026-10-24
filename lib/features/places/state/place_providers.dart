import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/mapbox_config.dart';
import '../../../core/models/selected_site.dart';
import '../../explore/state/explore_controller.dart';
import '../data/place_repository.dart';
import '../domain/place.dart';

final placeRepositoryProvider = Provider<PlaceRepository>(
  (ref) => MapboxPlaceRepository.fromConfig(),
);

/// Readable label for a point. Coordinates stay the source of truth; this
/// is display only. Failures are not retried automatically: the label
/// widget offers a Retry button instead, so a dead connection never turns
/// into a stream of requests.
final placeLabelProvider = FutureProvider.family<PlaceLabel, GeoPoint>(
  (ref, point) => ref.watch(placeRepositoryProvider).labelFor(point),
  retry: (_, _) => null,
);

GeoPoint pointOf(SelectedSite site) =>
    (latitude: site.latitude, longitude: site.longitude);

enum PlaceSearchStatus { idle, loading, results, empty, error }

@immutable
class PlaceSearchState {
  const PlaceSearchState({
    this.status = PlaceSearchStatus.idle,
    this.query = '',
    this.results = const [],
    this.failure,
  });

  final PlaceSearchStatus status;
  final String query;
  final List<PlaceResult> results;
  final GeocodingFailure? failure;

  bool get isOpen => status != PlaceSearchStatus.idle;
}

/// "Search a place or address": one request per explicit submit, the
/// previous request cancelled, results biased toward the current site.
class PlaceSearchController extends Notifier<PlaceSearchState> {
  CancelToken? _cancel;

  @override
  PlaceSearchState build() {
    ref.onDispose(() => _cancel?.cancel());
    return const PlaceSearchState();
  }

  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) {
      state = const PlaceSearchState();
      return;
    }
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    state = PlaceSearchState(status: PlaceSearchStatus.loading, query: query);

    final site = ref.read(exploreControllerProvider).site;
    final near = site != null
        ? pointOf(site)
        : (latitude: MapDefaults.latitude, longitude: MapDefaults.longitude);
    try {
      final results = await ref
          .read(placeRepositoryProvider)
          .search(query, near: near, cancelToken: cancel);
      if (!ref.mounted || cancel.isCancelled) return;
      state = PlaceSearchState(
        status: results.isEmpty
            ? PlaceSearchStatus.empty
            : PlaceSearchStatus.results,
        query: query,
        results: results,
      );
    } on GeocodingCancelled {
      return;
    } on GeocodingException catch (e) {
      if (!ref.mounted || cancel.isCancelled) return;
      state = PlaceSearchState(
        status: PlaceSearchStatus.error,
        query: query,
        failure: e.failure,
      );
    }
  }

  /// Makes [place] the site, at the result's own coordinates.
  void choose(PlaceResult place) {
    final point = (latitude: place.latitude, longitude: place.longitude);
    ref
        .read(placeRepositoryProvider)
        .remember(point, PlaceLabel.searched(place));
    ref
        .read(exploreControllerProvider.notifier)
        .selectSite(
          latitude: place.latitude,
          longitude: place.longitude,
          source: SiteSource.search,
        );
    close();
  }

  void close() {
    _cancel?.cancel();
    _cancel = null;
    state = const PlaceSearchState();
  }
}

final placeSearchControllerProvider =
    NotifierProvider<PlaceSearchController, PlaceSearchState>(
      PlaceSearchController.new,
    );

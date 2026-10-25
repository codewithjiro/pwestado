import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/selected_site.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';
import 'package:pwestado/features/places/data/geocoding_client.dart';
import 'package:pwestado/features/places/data/place_repository.dart';
import 'package:pwestado/features/places/domain/place.dart';
import 'package:pwestado/features/places/state/place_providers.dart';

import '../fake_place_repository.dart';

Object? fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync());

/// Answers every request with [status] and [body], and records the URIs.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

  final int status;
  final Object? body;
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

GeocodingClient _clientWith(_StubAdapter adapter) => GeocodingClient(
  dio: Dio(BaseOptions(baseUrl: GeocodingConfig.endpoint))
    ..httpClientAdapter = adapter,
  accessToken: 'pk.test',
);

void main() {
  group('parser', () {
    test('reads names, area and coordinates of forward results', () {
      final places = parseGeocodingFeatures(fixture('geocode_forward.json'));
      expect(places, hasLength(5));
      expect(places.first.name, 'San Fernando');
      expect(places.first.placeFormatted, 'Pampanga, Philippines');
      expect(places.first.featureType, 'place');
      expect(places.first.latitude, 15.027807);
      expect(places.first.longitude, 120.69343);
    });

    test('skips features without a name or coordinates', () {
      final places = parseGeocodingFeatures({
        'features': [
          {
            'properties': {'name': 'No coordinates'},
          },
          {
            'properties': {
              'name': '  ',
              'coordinates': {'latitude': 1, 'longitude': 2},
            },
          },
          {
            'properties': {
              'name': 'Kept',
              'coordinates': {'latitude': 1, 'longitude': 2},
            },
          },
        ],
      });
      expect(places.map((p) => p.name), ['Kept']);
    });

    test('a payload without features is a bad response', () {
      expect(
        () => parseGeocodingFeatures({'message': 'x'}),
        throwsA(
          isA<GeocodingException>().having(
            (e) => e.failure,
            'failure',
            GeocodingFailure.badResponse,
          ),
        ),
      );
    });
  });

  group('labels', () {
    test('street-level reverse results say "Near ..."', () {
      final place = parseGeocodingFeatures(
        fixture('geocode_reverse.json'),
      ).single;
      final label = PlaceLabel.near(place);
      expect(label.title, 'Near Baliwag-Candaba-Santa Ana Road');
      expect(label.subtitle, 'Santa Lucia, Santa Ana, Pampanga, Philippines');
      expect(label.approximate, isTrue);
    });

    test('area-level results and searched places use the plain name', () {
      const area = PlaceResult(
        id: 'p',
        name: 'San Fernando',
        placeFormatted: 'Pampanga, Philippines',
        featureType: 'place',
        latitude: 15,
        longitude: 120,
      );
      expect(PlaceLabel.near(area).title, 'San Fernando');
      expect(PlaceLabel.searched(area).approximate, isFalse);
    });
  });

  group('client', () {
    test('forward sends the query, PH filter, proximity and token', () async {
      final adapter = _StubAdapter(200, fixture('geocode_forward.json'));
      final places = await _clientWith(
        adapter,
      ).forward('San Fernando', near: (latitude: 15.09, longitude: 120.76));

      expect(places, hasLength(5));
      final uri = adapter.requests.single;
      expect(uri.path, endsWith('/search/geocode/v6/forward'));
      expect(uri.queryParameters['q'], 'San Fernando');
      expect(uri.queryParameters['country'], 'ph');
      expect(uri.queryParameters['proximity'], '120.76,15.09');
      expect(uri.queryParameters['access_token'], 'pk.test');
    });

    test('reverse returns null when Mapbox has nothing there', () async {
      final adapter = _StubAdapter(200, {'features': <Object>[]});
      expect(await _clientWith(adapter).reverse(1, 2), isNull);
      expect(adapter.requests.single.path, endsWith('/reverse'));
    });

    for (final (status, failure) in [
      (401, GeocodingFailure.unauthorized),
      (403, GeocodingFailure.unauthorized),
      (429, GeocodingFailure.rateLimited),
      (500, GeocodingFailure.badResponse),
    ]) {
      test('HTTP $status maps to ${failure.name}', () {
        final adapter = _StubAdapter(status, {'message': 'nope'});
        expect(
          _clientWith(adapter).forward('x y'),
          throwsA(
            isA<GeocodingException>()
                .having((e) => e.failure, 'failure', failure)
                .having((e) => e.statusCode, 'statusCode', status),
          ),
        );
      });
    }
  });

  group('repository', () {
    test('caches reverse labels and remembers searched places', () async {
      final adapter = _StubAdapter(200, fixture('geocode_reverse.json'));
      final client = _clientWith(adapter);
      final repo = MapboxPlaceRepository(client);
      const point = (latitude: 15.0939, longitude: 120.7681);

      final first = await repo.labelFor(point);
      final second = await repo.labelFor(point);
      expect(first.title, 'Near Baliwag-Candaba-Santa Ana Road');
      expect(second, first);
      expect(client.requestCount, 1);

      const other = (latitude: 15.03, longitude: 120.69);
      repo.remember(other, const PlaceLabel(title: 'Picked'));
      expect((await repo.labelFor(other)).title, 'Picked');
      expect(client.requestCount, 1);
    });

    test('nothing nearby gives the honest fallback', () async {
      final repo = MapboxPlaceRepository(
        _clientWith(_StubAdapter(200, {'features': <Object>[]})),
      );
      final label = await repo.labelFor((latitude: 0, longitude: 0));
      expect(label, PlaceLabel.fallback);
      expect(label.title, 'Selected location');
    });

    test('without a token, labels fall back and search reports it', () async {
      final repo = MapboxPlaceRepository(null);
      expect(
        await repo.labelFor((latitude: 1, longitude: 2)),
        PlaceLabel.fallback,
      );
      expect(
        () => repo.search('x y'),
        throwsA(
          isA<GeocodingException>().having(
            (e) => e.failure,
            'failure',
            GeocodingFailure.noToken,
          ),
        ),
      );
    });
  });

  group('search controller', () {
    late FakePlaceRepository places;
    late ProviderContainer container;

    setUp(() {
      places = FakePlaceRepository();
      container = ProviderContainer(
        overrides: [placeRepositoryProvider.overrideWithValue(places)],
      );
    });
    tearDown(() => container.dispose());

    PlaceSearchController controller() =>
        container.read(placeSearchControllerProvider.notifier);
    PlaceSearchState state() => container.read(placeSearchControllerProvider);

    test('ignores one-letter queries', () async {
      await controller().search(' a ');
      expect(state().status, PlaceSearchStatus.idle);
      expect(places.searches, isEmpty);
    });

    test('shortening the query drops a slower earlier search', () async {
      final slow = places.pendingSearch = Completer<List<PlaceResult>>();
      final first = controller().search('San Fernando');
      expect(state().status, PlaceSearchStatus.loading);

      await controller().search('S');
      expect(state().status, PlaceSearchStatus.idle);

      slow.complete([FakePlaceRepository.sanFernando]);
      await first;
      expect(state().status, PlaceSearchStatus.idle);
      expect(state().results, isEmpty);
    });

    test('lists results, then choosing one sets the site', () async {
      await controller().search('San Fernando');
      expect(state().status, PlaceSearchStatus.results);
      expect(places.searches, ['San Fernando']);

      controller().choose(state().results.first);
      final site = container.read(exploreControllerProvider).site!;
      expect(site.source, SiteSource.search);
      expect(site.latitude, FakePlaceRepository.sanFernando.latitude);
      expect(state().status, PlaceSearchStatus.idle);
      // The picked name is reused as the label without a reverse request.
      final label = await container.read(
        placeLabelProvider(pointOf(site)).future,
      );
      expect(label.title, 'San Fernando');
      expect(places.reverseLookups, 0);
    });

    test('no matches and failures are reported', () async {
      places.results = [];
      await controller().search('zzqx');
      expect(state().status, PlaceSearchStatus.empty);

      places.failure = GeocodingFailure.network;
      await controller().search('San Fernando');
      expect(state().status, PlaceSearchStatus.error);
      expect(state().failure, GeocodingFailure.network);
    });
  });
}

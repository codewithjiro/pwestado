import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/discovery/data/competitor_repository.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';

/// Records requests and answers them with [handler].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  Future<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object json, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody textBody(String text, int status) => ResponseBody.fromString(
  text,
  status,
  headers: {
    Headers.contentTypeHeader: ['text/html'],
  },
);

const query = CompetitorQuery(
  latitude: 15.0336,
  longitude: 120.6844,
  category: BusinessCategory.coffeeShop,
  radius: SearchRadius.km1,
);

final oneCafe = {
  'elements': [
    {
      'type': 'node',
      'id': 42,
      'lat': 15.0340,
      'lon': 120.6850,
      'tags': {'amenity': 'cafe', 'name': 'Test Cafe'},
    },
  ],
};

void main() {
  late FakeAdapter adapter;
  late DateTime now;
  late OverpassCompetitorRepository repo;

  setUp(() {
    now = DateTime(2026, 10, 22, 10);
    adapter = FakeAdapter((_) async => jsonBody(oneCafe));
    final dio = createOverpassDio()..httpClientAdapter = adapter;
    repo = OverpassCompetitorRepository(
      dio: dio,
      clock: () => now,
      retryDelay: Duration.zero,
    );
  });

  test('POSTs the query as form data with a User-Agent', () async {
    final result = await repo.fetch(query);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.toString(), OverpassConfig.endpoint);
    expect(request.headers[HttpHeaders.userAgentHeader], contains('PWESTADO'));
    expect(request.contentType, Headers.formUrlEncodedContentType);
    final ql = (request.data as Map)['data'] as String;
    expect(ql, contains('nwr(around:1000,15.033600,120.684400)'));
    expect(ql, contains('["amenity"="cafe"]'));

    expect(result.source, DataSource.live);
    expect(result.fetchedAt, now);
    expect(result.businesses.single.name, 'Test Cafe');
    expect(result.businesses.single.distanceMeters, greaterThan(0));
  });

  test('a successful empty response is a result, not an error', () async {
    adapter.handler = (_) async => jsonBody({'elements': <Object>[]});
    final result = await repo.fetch(query);
    expect(result.isEmpty, isTrue);
    expect(result.source, DataSource.live);
  });

  test('accepts JSON served with a text content type', () async {
    adapter.handler = (_) async => textBody(jsonEncode(oneCafe), 200);
    final result = await repo.fetch(query);
    expect(result.count, 1);
  });

  group('cache', () {
    test('repeats are served from cache and labeled cached', () async {
      await repo.fetch(query);
      now = now.add(const Duration(minutes: 5));
      final second = await repo.fetch(query);

      expect(adapter.requests, hasLength(1));
      expect(second.source, DataSource.cached);
      expect(second.fetchedAt, DateTime(2026, 10, 22, 10));
    });

    test('a different category or radius is a separate query', () async {
      await repo.fetch(query);
      await repo.fetch(
        const CompetitorQuery(
          latitude: 15.0336,
          longitude: 120.6844,
          category: BusinessCategory.bakery,
          radius: SearchRadius.km1,
        ),
      );
      expect(adapter.requests, hasLength(2));
    });

    test('is reused within the TTL and expires after it', () async {
      final start = now;
      await repo.fetch(query);
      now = start.add(OverpassConfig.cacheTtl - const Duration(minutes: 1));
      final cached = await repo.fetch(query);
      expect(adapter.requests, hasLength(1));
      expect(cached.source, DataSource.cached);

      now = start.add(OverpassConfig.cacheTtl + const Duration(minutes: 1));
      final again = await repo.fetch(query);
      expect(adapter.requests, hasLength(2));
      expect(again.source, DataSource.live);
    });

    test('forceRefresh refetches, except right after a fetch', () async {
      await repo.fetch(query);
      now = now.add(const Duration(seconds: 10));
      final throttled = await repo.fetch(query, forceRefresh: true);
      expect(adapter.requests, hasLength(1));
      expect(throttled.source, DataSource.cached);

      now = now.add(const Duration(minutes: 1));
      final fresh = await repo.fetch(query, forceRefresh: true);
      expect(adapter.requests, hasLength(2));
      expect(fresh.source, DataSource.live);
    });

    test('failures are not cached', () async {
      adapter.handler = (_) async => textBody('busy', 504);
      await expectLater(repo.fetch(query), throwsA(isA<Exception>()));
      adapter.handler = (_) async => jsonBody(oneCafe);
      final result = await repo.fetch(query);
      expect(result.source, DataSource.live);
    });
  });

  group('errors', () {
    Matcher fails(CompetitorFailure failure, {int? status}) => throwsA(
      isA<CompetitorFetchException>()
          .having((e) => e.failure, 'failure', failure)
          .having((e) => e.statusCode, 'statusCode', status),
    );

    test('429 is rate-limited and never retried', () async {
      adapter.handler = (_) async => textBody('rate_limited', 429);
      await expectLater(
        repo.fetch(query),
        fails(CompetitorFailure.rateLimited, status: 429),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('504 is retried twice, then reported as server busy', () async {
      adapter.handler = (_) async => textBody('Gateway Timeout', 504);
      await expectLater(
        repo.fetch(query),
        fails(CompetitorFailure.serverBusy, status: 504),
      );
      expect(adapter.requests, hasLength(3));
    });

    test('fast 502s followed by success recover (observed live)', () async {
      var calls = 0;
      adapter.handler = (_) async =>
          ++calls < 3 ? textBody('Bad Gateway', 502) : jsonBody(oneCafe);
      final result = await repo.fetch(query);
      expect(result.count, 1);
      expect(adapter.requests, hasLength(3));
    });

    test('a transient 504 followed by success recovers', () async {
      var calls = 0;
      adapter.handler = (_) async =>
          ++calls == 1 ? textBody('busy', 504) : jsonBody(oneCafe);
      final result = await repo.fetch(query);
      expect(result.count, 1);
      expect(adapter.requests, hasLength(2));
    });

    test('a receive timeout is reported without retrying', () async {
      adapter.handler = (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
      await expectLater(repo.fetch(query), fails(CompetitorFailure.timeout));
      expect(adapter.requests, hasLength(1));
    });

    test('no network is retried once, then reported', () async {
      adapter.handler = (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup',
        error: const SocketException('Failed host lookup'),
      );
      await expectLater(repo.fetch(query), fails(CompetitorFailure.network));
      expect(adapter.requests, hasLength(2));
    });

    test('406 and other HTTP errors are bad responses', () async {
      adapter.handler = (_) async => textBody('Not Acceptable', 406);
      await expectLater(
        repo.fetch(query),
        fails(CompetitorFailure.badResponse, status: 406),
      );
    });

    test('a non-Overpass payload is a bad response', () async {
      adapter.handler = (_) async => textBody('<html>oops</html>', 200);
      await expectLater(
        repo.fetch(query),
        fails(CompetitorFailure.badResponse),
      );
    });

    test('an Overpass runtime timeout remark is a timeout', () async {
      adapter.handler = (_) async => jsonBody({
        'elements': <Object>[],
        'remark': 'runtime error: Query timed out in "query" at line 1',
      });
      await expectLater(repo.fetch(query), fails(CompetitorFailure.timeout));
    });

    test('cancellation is reported as cancelled, not an error', () async {
      final gate = Completer<ResponseBody>();
      adapter.handler = (_) => gate.future;
      final token = CancelToken();
      final future = repo.fetch(query, cancelToken: token);
      token.cancel();
      await expectLater(future, throwsA(isA<CompetitorSearchCancelled>()));
      gate.complete(jsonBody(oneCafe));
    });
  });

  test('classifyDioException maps every kind', () {
    final options = RequestOptions(path: '/');
    DioException bad(int status) => DioException.badResponse(
      statusCode: status,
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: status),
    );
    expect(classifyDioException(bad(429)), CompetitorFailure.rateLimited);
    expect(classifyDioException(bad(502)), CompetitorFailure.serverBusy);
    expect(classifyDioException(bad(503)), CompetitorFailure.serverBusy);
    expect(classifyDioException(bad(400)), CompetitorFailure.badResponse);
    expect(
      classifyDioException(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      ),
      CompetitorFailure.timeout,
    );
    expect(
      classifyDioException(
        DioException(
          requestOptions: options,
          error: const SocketException('down'),
        ),
      ),
      CompetitorFailure.network,
    );
  });
}

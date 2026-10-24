import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/features/discovery/data/business_image_repository.dart';
import 'package:pwestado/features/discovery/data/overpass_parser.dart';
import 'package:pwestado/features/discovery/domain/business_image.dart';

import '../support/fake_http.dart';

Map<String, Object?> commonsInfo({
  String license = 'CC BY-SA 4.0',
  String? artist = '<a href="//x">Juan dela Cruz</a>',
  String mime = 'image/jpeg',
  String thumb =
      'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Store.jpg/320px-Store.jpg',
}) => {
  'query': {
    'pages': [
      {
        'title': 'File:Store.jpg',
        'imageinfo': [
          {
            'mime': mime,
            'thumburl': thumb,
            'descriptionurl':
                'https://commons.wikimedia.org/wiki/File:Store.jpg',
            'extmetadata': {
              'LicenseShortName': {'value': license},
              'Artist': ?(artist == null ? null : {'value': artist}),
            },
          },
        ],
      },
    ],
  },
};

Map<String, Object?> claims(String property, String file) => {
  'claims': {
    property: [
      {
        'rank': 'normal',
        'mainsnak': {
          'datavalue': {'value': file},
        },
      },
    ],
  },
};

void main() {
  group('BusinessImageRefs.fromTags', () {
    test('keeps Commons files, Commons URLs and valid Wikidata ids', () {
      expect(
        BusinessImageRefs.fromTags({
          'wikimedia_commons': 'File:Jollibee_store.jpg',
        })?.commonsFile,
        'Jollibee store.jpg',
      );
      expect(
        BusinessImageRefs.fromTags({
          'image': 'https://commons.wikimedia.org/wiki/File:Kape%20Uno.png',
        })?.commonsFile,
        'Kape Uno.png',
      );
      expect(
        BusinessImageRefs.fromTags({
          'image':
              'https://upload.wikimedia.org/wikipedia/commons/a/ab/Bakery.jpg',
        })?.commonsFile,
        'Bakery.jpg',
      );
      final refs = BusinessImageRefs.fromTags({
        'wikidata': 'Q123',
        'brand:wikidata': 'Q456',
        'brand': 'Jollibee',
      })!;
      expect(refs.wikidata, 'Q123');
      expect(refs.brandWikidata, 'Q456');
      expect(refs.brandName, 'Jollibee');
    });

    test('ignores images with unknown licenses and malformed values', () {
      for (final tags in [
        {'image': 'https://example.com/photo.jpg'},
        {'image': 'https://lh3.googleusercontent.com/abc'},
        {'wikimedia_commons': 'Category:Jollibee'},
        {'wikimedia_commons': 'File:notes.pdf'},
        {'wikidata': 'Jollibee'},
        {'brand:wikidata': 'Q0'},
        <String, String>{},
      ]) {
        expect(BusinessImageRefs.fromTags(tags), isNull, reason: '$tags');
      }
    });

    test('a branch tagged with the brand item is treated as brand-level', () {
      final refs = BusinessImageRefs.fromTags({
        'wikidata': 'Q456',
        'brand:wikidata': 'Q456',
      })!;
      expect(refs.wikidata, isNull);
      expect(refs.hasBusinessRef, isFalse);
      expect(refs.brandWikidata, 'Q456');
    });

    test('the Overpass parser attaches references', () {
      final result = parseOverpassResponse(
        {
          'elements': [
            {
              'type': 'node',
              'id': 1,
              'lat': 15.0,
              'lon': 120.0,
              'tags': {'name': 'Jollibee', 'brand:wikidata': 'Q1068143'},
            },
            {
              'type': 'node',
              'id': 2,
              'lat': 15.001,
              'lon': 120.0,
              'tags': {'name': 'Kape'},
            },
          ],
        },
        originLatitude: 15.0,
        originLongitude: 120.0,
      );
      expect(result.businesses[0].imageRefs?.brandWikidata, 'Q1068143');
      expect(result.businesses[1].imageRefs, isNull);
    });
  });

  group('parseCommonsImageInfo', () {
    test('extracts thumbnail, page, license and plain-text author', () {
      final image = parseCommonsImageInfo(
        commonsInfo(),
        kind: BusinessImageKind.place,
      )!;
      expect(image.thumbnailUrl, contains('320px-'));
      expect(image.license, 'CC BY-SA 4.0');
      expect(image.author, 'Juan dela Cruz');
      expect(image.credit, 'Juan dela Cruz · CC BY-SA 4.0 · Wikimedia Commons');
      expect(image.isBrandLevel, isFalse);
    });

    test('refuses images without a license, non-images and foreign hosts', () {
      expect(
        parseCommonsImageInfo(
          commonsInfo(license: ''),
          kind: BusinessImageKind.place,
        ),
        isNull,
      );
      expect(
        parseCommonsImageInfo(
          commonsInfo(mime: 'application/pdf'),
          kind: BusinessImageKind.place,
        ),
        isNull,
      );
      expect(
        parseCommonsImageInfo(
          commonsInfo(thumb: 'https://evil.example/x.jpg'),
          kind: BusinessImageKind.place,
        ),
        isNull,
      );
    });

    test('brand images are labeled as not this branch', () {
      final logo = parseCommonsImageInfo(
        commonsInfo(),
        kind: BusinessImageKind.brandLogo,
      )!;
      expect(logo.isBrandLevel, isTrue);
      expect(logo.kindLabel, contains('not a photo of this branch'));
    });
  });

  group('BusinessImageRepository', () {
    test(
      'prefers the place image, then falls back to the brand logo',
      () async {
        final adapter = FakeHttpAdapter((o) async {
          final p = o.queryParameters;
          if (p['action'] == 'wbgetclaims' && p['entity'] == 'Q1') {
            return jsonResponse({'claims': <String, Object?>{}});
          }
          if (p['action'] == 'wbgetclaims' && p['property'] == 'P154') {
            return jsonResponse(claims('P154', 'Brand logo.svg'));
          }
          return jsonResponse(commonsInfo());
        });
        final repo = BusinessImageRepository(dio: fakeDio(adapter));
        final image = await repo.resolve(
          const BusinessImageRefs(wikidata: 'Q1', brandWikidata: 'Q2'),
        );
        expect(image?.kind, BusinessImageKind.brandLogo);
        final titles = adapter.requests
            .map((r) => r.queryParameters['titles'])
            .whereType<String>();
        expect(titles, ['File:Brand logo.svg']);
        expect(
          adapter.requests.every(
            (r) =>
                r.uri.host.endsWith('wikidata.org') ||
                r.uri.host.endsWith('wikimedia.org'),
          ),
          isTrue,
        );
      },
    );

    test('caches results, including "no image"', () async {
      final adapter = FakeHttpAdapter(
        (_) async => jsonResponse({'claims': <String, Object?>{}}),
      );
      final repo = BusinessImageRepository(dio: fakeDio(adapter));
      const refs = BusinessImageRefs(brandWikidata: 'Q9');
      expect(await repo.resolve(refs), isNull);
      final sent = adapter.requests.length;
      expect(await repo.resolve(refs), isNull);
      expect(adapter.requests.length, sent);
    });

    test('network errors fall back to no image', () async {
      final adapter = FakeHttpAdapter(
        (_) async => jsonResponse({'error': 'x'}, status: 500),
      );
      final repo = BusinessImageRepository(dio: fakeDio(adapter));
      expect(
        await repo.resolve(const BusinessImageRefs(commonsFile: 'A.jpg')),
        isNull,
      );
    });

    test('runs at most maxConcurrent requests at once', () async {
      var inFlight = 0;
      var peak = 0;
      final adapter = FakeHttpAdapter((_) async {
        inFlight++;
        peak = peak < inFlight ? inFlight : peak;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return jsonResponse(commonsInfo());
      });
      final repo = BusinessImageRepository(dio: fakeDio(adapter));
      await Future.wait([
        for (var i = 0; i < 6; i++)
          repo.resolve(BusinessImageRefs(commonsFile: 'F$i.jpg')),
      ]);
      expect(peak, lessThanOrEqualTo(2));
    });
  });
}

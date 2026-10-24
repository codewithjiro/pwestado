import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/business_type_search.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/discovery/data/overpass_query.dart';

void main() {
  group('SearchRadius', () {
    test('presets are 250 m, 500 m, 1 km and 2 km', () {
      expect(SearchRadius.presets.map((r) => r.meters), [250, 500, 1000, 2000]);
      expect(SearchRadius.presets.map((r) => r.label), [
        '250 m',
        '500 m',
        '1 km',
        '2 km',
      ]);
    });

    test('equal meters are the same radius, preset or custom', () {
      expect(SearchRadius.meters(1000), SearchRadius.km1);
      expect(SearchRadius.meters(1000).hashCode, SearchRadius.km1.hashCode);
      expect(SearchRadius.parse('1000').radius, SearchRadius.km1);
      expect(SearchRadius.meters(1000).isPreset, isTrue);
      expect(SearchRadius.meters(750).isPreset, isFalse);
      expect({SearchRadius.km1, SearchRadius.meters(1000)}, hasLength(1));
    });

    test('labels read naturally', () {
      expect(SearchRadius.meters(100).label, '100 m');
      expect(SearchRadius.meters(750).label, '750 m');
      expect(SearchRadius.meters(1500).label, '1.5 km');
      expect(SearchRadius.meters(1250).label, '1,250 m');
      expect(SearchRadius.meters(2000).label, '2 km');
    });

    test('the range is 100..2000 m', () {
      expect(SearchRadius.tryMeters(99), isNull);
      expect(SearchRadius.tryMeters(100)?.meters, 100);
      expect(SearchRadius.tryMeters(2000)?.meters, 2000);
      expect(SearchRadius.tryMeters(2001), isNull);
      expect(() => SearchRadius.meters(0), throwsArgumentError);
      expect(SearchRadius.maxMeters, OverpassQuery.maxRadiusMeters);
    });

    group('parse', () {
      void expectError(String text, RadiusInputError error) {
        final input = SearchRadius.parse(text);
        expect(input.isValid, isFalse, reason: text);
        expect(input.error, error, reason: text);
        expect(input.error!.message, isNotEmpty);
      }

      test('accepts whole meters, with spaces or separators', () {
        expect(SearchRadius.parse('750').radius?.meters, 750);
        expect(SearchRadius.parse(' 300 ').radius?.meters, 300);
        expect(SearchRadius.parse('1,500').radius?.meters, 1500);
        expect(SearchRadius.parse('+1200').radius?.meters, 1200);
      });

      test('explains every invalid entry', () {
        expectError('', RadiusInputError.empty);
        expectError('   ', RadiusInputError.empty);
        expectError('-300', RadiusInputError.negative);
        expectError('abc', RadiusInputError.notANumber);
        expectError('1e3', RadiusInputError.notANumber);
        expectError('750m', RadiusInputError.notANumber);
        expectError('1.5', RadiusInputError.decimal);
        expectError('750.0', RadiusInputError.decimal);
        expectError('.5', RadiusInputError.decimal);
        expectError('50', RadiusInputError.tooSmall);
        expectError('0', RadiusInputError.tooSmall);
        expectError('2001', RadiusInputError.tooLarge);
        expectError('99999999999999999999', RadiusInputError.tooLarge);
      });
    });
  });

  group('catalog', () {
    test('ids and OSM tags are unique', () {
      final ids = BusinessCategory.all.map((c) => c.id).toList();
      final tags = BusinessCategory.all.map((c) => c.osmTag).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(tags.toSet(), hasLength(tags.length));
      for (final c in BusinessCategory.all) {
        expect(BusinessCategory.byId(c.id), same(c));
      }
      expect(BusinessCategory.byId('karaoke_bar'), isNull);
    });

    test('every category uses an allowed key and a plain value', () {
      for (final c in BusinessCategory.all) {
        expect(OverpassQuery.allowedKeys, contains(c.osmTagKey), reason: c.id);
        expect(c.osmTagValue, matches(RegExp(r'^[a-z][a-z0-9_]*$')));
        expect(c.description, isNotEmpty, reason: c.id);
      }
    });

    test('the requested categories map to their documented OSM tags', () {
      String tag(String id) => BusinessCategory.byId(id)!.osmTag;
      expect(
        {
          for (final id in [
            'barbershop_hairdresser',
            'beauty_salon',
            'pharmacy',
            'hardware',
            'car_wash',
            'auto_repair',
            'gas_station',
            'gym',
            'supermarket',
            'clothing',
            'electronics',
            'mobile_phone',
            'pet_shop',
            'bookstore',
            'florist',
            'furniture',
            'motorcycle_shop',
            'bicycle_shop',
            'optical_shop',
            'variety_store',
          ])
            id: tag(id),
        },
        {
          'barbershop_hairdresser': 'shop=hairdresser',
          'beauty_salon': 'shop=beauty',
          'pharmacy': 'amenity=pharmacy',
          'hardware': 'shop=hardware',
          'car_wash': 'amenity=car_wash',
          'auto_repair': 'shop=car_repair',
          'gas_station': 'amenity=fuel',
          // amenity=gym is deprecated on the OSM wiki.
          'gym': 'leisure=fitness_centre',
          'supermarket': 'shop=supermarket',
          'clothing': 'shop=clothes',
          'electronics': 'shop=electronics',
          'mobile_phone': 'shop=mobile_phone',
          'pet_shop': 'shop=pet',
          'bookstore': 'shop=books',
          'florist': 'shop=florist',
          'furniture': 'shop=furniture',
          'motorcycle_shop': 'shop=motorcycle',
          'bicycle_shop': 'shop=bicycle',
          'optical_shop': 'shop=optician',
          'variety_store': 'shop=variety_store',
        },
      );
    });

    test('barbershop discloses that it includes hair salons', () {
      const barber = BusinessCategory.barbershop;
      expect(barber.osmTag, 'shop=hairdresser');
      expect(barber.coverageNote, contains('both barbershops and hair salons'));
    });

    test('no alias points at two categories', () {
      final owner = <String, String>{};
      for (final c in BusinessCategory.all) {
        for (final alias in c.aliases) {
          final key = BusinessTypeSearch.normalize(alias);
          final previous = owner[key];
          expect(
            previous == null || previous == c.id,
            isTrue,
            reason: '"$alias" is used by $previous and ${c.id}',
          );
          owner[key] = c.id;
        }
      }
    });
  });

  group('search', () {
    BusinessCategory top(String q) =>
        BusinessTypeSearch.search(q).first.category;

    test('an empty query lists every category in catalog order', () {
      expect(
        BusinessTypeSearch.search('  ').map((h) => h.category),
        BusinessCategory.all,
      );
    });

    test('finds categories by label, Filipino terms and aliases', () {
      expect(top('pharm'), BusinessCategory.pharmacy);
      expect(top('botika'), BusinessCategory.pharmacy);
      expect(top('drugstore'), BusinessCategory.pharmacy);
      expect(top('barber'), BusinessCategory.barbershop);
      expect(top('gupitan'), BusinessCategory.barbershop);
      expect(top('sari-sari'), BusinessCategory.convenience);
      expect(top('vulcanizing'), BusinessCategory.tyres);
      expect(top('ukay'), BusinessCategory.thrift);
      expect(top('panaderya'), BusinessCategory.bakery);
      expect(top('Café'), BusinessCategory.coffeeShop);
      expect(top('gasolinahan'), BusinessCategory.gasStation);
      expect(top('pisonet'), BusinessCategory.internetCafe);
    });

    test('multi-word prefixes match', () {
      expect(
        BusinessTypeSearch.search('hair sal').map((h) => h.category),
        contains(BusinessCategory.barbershop),
      );
    });

    test('reports which alias matched', () {
      final hit = BusinessTypeSearch.search('botika').first;
      expect(hit.matchedAlias, 'botika');
      expect(BusinessTypeSearch.search('Pharmacy').first.matchedAlias, isNull);
    });

    test('nonsense finds nothing', () {
      expect(BusinessTypeSearch.search('qwxz'), isEmpty);
    });
  });

  group('resolve (other business type)', () {
    BusinessTypeResolution resolve(String text) =>
        BusinessTypeSearch.resolve(text);

    BusinessCategory matched(String text) {
      final r = resolve(text);
      expect(r, isA<BusinessTypeMatch>(), reason: text);
      return (r as BusinessTypeMatch).category;
    }

    test('maps the owner examples to verified categories', () {
      expect(matched('Computer Repair'), BusinessCategory.electronicsRepair);
      expect(matched('Printing Shop'), BusinessCategory.printing);
      expect(
        matched('Water Refilling Station'),
        BusinessCategory.waterRefilling,
      );
      expect(matched('Motorcycle Parts Shop'), BusinessCategory.motorcycleShop);
    });

    test('exact names are exact; partial ones ask for confirmation', () {
      expect((resolve('printing shop') as BusinessTypeMatch).exact, isTrue);
      expect(
        (resolve('motorcycle parts shop') as BusinessTypeMatch).exact,
        isFalse,
      );
      expect(
        (resolve('cellphone repair near school') as BusinessTypeMatch).category,
        BusinessCategory.electronicsRepair,
      );
    });

    test('unsupported trades are explained, with related categories', () {
      final rice = resolve('Bigasan');
      expect(rice, isA<BusinessTypeUnsupported>());
      expect(
        (rice as BusinessTypeUnsupported).related,
        contains(BusinessCategory.convenience),
      );

      final lpg = resolve('LPG gas refill');
      expect(lpg, isA<BusinessTypeUnsupported>(), reason: 'not a gas station');

      final unknown = resolve('crypto mining farm');
      expect(unknown, isA<BusinessTypeUnsupported>());
      expect(
        (unknown as BusinessTypeUnsupported).message,
        BusinessTypeSearch.genericUnsupported,
      );
    });

    test('unknown words never guess a category', () {
      for (final text in ['zzzz shop', 'my business', 'store ng tita']) {
        expect(resolve(text), isA<BusinessTypeUnsupported>(), reason: text);
      }
    });

    test('rejects empty, overlong and non-word input', () {
      expect(resolve(''), isA<BusinessTypeInvalid>());
      expect(resolve('   '), isA<BusinessTypeInvalid>());
      expect(resolve('x' * 61), isA<BusinessTypeInvalid>());
      expect(resolve('12345'), isA<BusinessTypeInvalid>());
      expect(resolve('!!!'), isA<BusinessTypeInvalid>());
    });

    test('query syntax in the input never reaches Overpass', () {
      // Punctuation is stripped and only catalog tags can be returned.
      final r = resolve('cafe"];out;node(1);(');
      expect(r, isA<BusinessTypeMatch>());
      expect((r as BusinessTypeMatch).category.osmTag, 'amenity=cafe');
      expect(resolve('["shop"~"."]'), isA<BusinessTypeUnsupported>());
    });
  });
}

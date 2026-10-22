import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/explore/state/explore_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('defaults to Coffee Shop, 1 km, no site, search disabled', () {
    final state = container.read(exploreControllerProvider);
    expect(state.category, BusinessCategory.coffeeShop);
    expect(state.category.osmTag, 'amenity=cafe');
    expect(state.radius, SearchRadius.km1);
    expect(state.radius.meters, 1000);
    expect(state.site, isNull);
    expect(state.canSearch, isFalse);
  });

  test('category and radius changes keep the other setting', () {
    final controller = container.read(exploreControllerProvider.notifier);
    controller.selectCategory(BusinessCategory.bakery);
    controller.selectRadius(SearchRadius.km2);

    final state = container.read(exploreControllerProvider);
    expect(state.category, BusinessCategory.bakery);
    expect(state.radius, SearchRadius.km2);
  });

  test('categories map to the agreed OSM tags', () {
    expect(BusinessCategory.all.map((c) => c.osmTag), [
      'amenity=cafe',
      'amenity=restaurant',
      'shop=convenience',
      'shop=laundry',
      'shop=bakery',
    ]);
  });
}

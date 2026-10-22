import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/business_category.dart';
import '../../../core/models/search_radius.dart';
import '../../../core/models/selected_site.dart';

@immutable
class ExploreState {
  const ExploreState({
    this.category = BusinessCategory.coffeeShop,
    this.radius = SearchRadius.km1,
    this.site,
  });

  final BusinessCategory category;
  final SearchRadius radius;

  /// Null until the user picks a location on the map.
  final SelectedSite? site;

  /// A competitor search needs a chosen site; category and radius always
  /// have a value.
  bool get canSearch => site != null;

  ExploreState copyWith({BusinessCategory? category, SearchRadius? radius}) {
    return ExploreState(
      category: category ?? this.category,
      radius: radius ?? this.radius,
      site: site,
    );
  }
}

class ExploreController extends Notifier<ExploreState> {
  @override
  ExploreState build() => const ExploreState();

  void selectCategory(BusinessCategory category) {
    state = state.copyWith(category: category);
  }

  void selectRadius(SearchRadius radius) {
    state = state.copyWith(radius: radius);
  }
}

final exploreControllerProvider =
    NotifierProvider<ExploreController, ExploreState>(ExploreController.new);

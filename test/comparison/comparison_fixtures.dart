import 'package:pwestado/core/models/business_category.dart';
import 'package:pwestado/core/models/search_radius.dart';
import 'package:pwestado/features/analysis/domain/site_analysis.dart';
import 'package:pwestado/features/analysis/domain/site_context.dart';
import 'package:pwestado/features/discovery/domain/competitors.dart';

import '../fake_competitor_repository.dart';
import '../fake_site_context_repository.dart';

/// Site A: Santa Ana reference center.
const siteA = (lat: 15.0939, lon: 120.7681);

/// Site B: about 700 m away.
const siteB = (lat: 15.1000, lon: 120.7700);

CompetitorQuery queryAt(
  ({double lat, double lon}) site, {
  BusinessCategory category = BusinessCategory.coffeeShop,
  SearchRadius radius = SearchRadius.km1,
}) => CompetitorQuery(
  latitude: site.lat,
  longitude: site.lon,
  category: category,
  radius: radius,
);

/// Three competitors (100 m, 200 m, 600 m) -> competitor criterion 75,
/// total 63.6 with [contextFor].
final threeCompetitors = [
  business(1, distance: 100),
  business(2, distance: 200),
  business(3, distance: 600),
];

/// Builds an analysis. Empty [businesses] give total 73.6; the
/// default three competitors give 63.6. [contextFailed] gives no total.
SiteAnalysis analysisAt(
  CompetitorQuery query, {
  List<NearbyBusiness>? businesses,
  DataSource source = DataSource.live,
  DataSource? contextSource,
  bool contextFailed = false,
  DateTime? fetchedAt,
}) {
  final competitors = resultFor(
    query,
    businesses ?? threeCompetitors,
    source: source,
    fetchedAt: fetchedAt,
  );
  if (contextFailed) {
    return SiteAnalysis.from(
      competitors: competitors,
      contextFailure: CompetitorFailure.serverBusy,
      contextStatusCode: 504,
    );
  }
  final context = contextFor(query, source: contextSource ?? source);
  return SiteAnalysis.from(
    competitors: competitors,
    context: SiteContextResult(
      query: context.query,
      complementary: context.complementary,
      roads: context.roads,
      fetchedAt: fetchedAt ?? context.fetchedAt,
      source: context.source,
    ),
  );
}

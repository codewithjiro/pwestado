/// Supported search radii. Capped at 2 km to keep Overpass queries small.
enum SearchRadius {
  m500(500, '500 m'),
  km1(1000, '1 km'),
  km2(2000, '2 km');

  const SearchRadius(this.meters, this.label);

  final int meters;
  final String label;
}

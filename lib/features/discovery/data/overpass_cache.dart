/// Small insertion-ordered TTL cache for Overpass results, keyed by query.
///
/// [relabel] turns a stored live result into its "cached" form, so the UI
/// can always tell a reused response from a fresh one.
class OverpassCache<T> {
  OverpassCache({
    required this.ttl,
    required this.maxEntries,
    required this.clock,
    required this.fetchedAt,
    required this.relabel,
  });

  final Duration ttl;
  final int maxEntries;
  final DateTime Function() clock;
  final DateTime Function(T value) fetchedAt;
  final T Function(T value) relabel;

  /// Insertion-ordered (Dart's default map), oldest first, for eviction.
  final _entries = <String, T>{};

  /// The entry for [key] if younger than [maxAge] (default [ttl]), relabeled.
  T? lookup(String key, {Duration? maxAge}) {
    final entry = _entries[key];
    if (entry == null) return null;
    final age = clock().difference(fetchedAt(entry));
    if (age > ttl) {
      _entries.remove(key);
      return null;
    }
    if (age > (maxAge ?? ttl)) return null;
    return relabel(entry);
  }

  void store(String key, T value) {
    _entries
      ..remove(key)
      ..[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}

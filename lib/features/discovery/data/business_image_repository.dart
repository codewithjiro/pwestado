import 'dart:async';
import 'dart:collection' show Queue;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/business_image.dart';
import 'overpass_client.dart';

/// Resolves [BusinessImageRefs] to a licensed Wikimedia Commons thumbnail.
///
/// * Only the Wikidata and Commons APIs are called, with an identifying
///   User-Agent as the Wikimedia API etiquette asks.
/// * At most [maxConcurrent] lookups run at once; nothing is prefetched:
///   a lookup starts only when a thumbnail is actually built.
/// * Results (including "no usable image") are memoized for the session in
///   a bounded LRU, so scrolling never repeats requests.
/// * Any failure falls back to "no image"; the caller shows category art.
class BusinessImageRepository {
  BusinessImageRepository({
    Dio? dio,
    this.maxConcurrent = 2,
    this.maxCacheEntries = 200,
    this.thumbnailWidth = 320,
  }) : _dio = dio ?? createWikimediaDio();

  static const wikidataApi = 'https://www.wikidata.org/w/api.php';
  static const commonsApi = 'https://commons.wikimedia.org/w/api.php';

  final Dio _dio;
  final int maxConcurrent;
  final int maxCacheEntries;

  /// Server-side thumbnail width in pixels. Big enough for a 112 dp detail
  /// image on a 3x screen; list tiles decode it smaller.
  final int thumbnailWidth;

  // Map literals keep insertion order, which makes this an LRU.
  final _cache = <String, Future<BusinessImage?>>{};
  final _waiting = Queue<Completer<void>>();
  int _running = 0;

  /// Number of HTTP requests sent; for tests.
  int requestCount = 0;

  Future<BusinessImage?> resolve(BusinessImageRefs refs) {
    final key = refs.cacheKey;
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // most recently used
      return cached;
    }
    final future = _resolve(refs);
    _cache[key] = future;
    while (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  Future<BusinessImage?> _resolve(BusinessImageRefs refs) async {
    try {
      // 1. Business-specific: the record's own Commons file or item image.
      final placeFile =
          refs.commonsFile ??
          (refs.wikidata == null
              ? null
              : await _claimFile(refs.wikidata!, 'P18'));
      if (placeFile != null) {
        final image = await _imageInfo(placeFile, BusinessImageKind.place);
        if (image != null) return image;
      }
      // 2. Brand-level: logo first (clearly not a branch photo), then image.
      final brand = refs.brandWikidata;
      if (brand != null) {
        final logo = await _claimFile(brand, 'P154');
        if (logo != null) {
          final image = await _imageInfo(logo, BusinessImageKind.brandLogo);
          if (image != null) return image;
        }
        final picture = await _claimFile(brand, 'P18');
        if (picture != null) {
          return await _imageInfo(picture, BusinessImageKind.brandImage);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Business image lookup failed: ${describeImageError(e)}');
      return null;
    }
  }

  /// The first file name in a Wikidata item's [property] claim.
  Future<String?> _claimFile(String qid, String property) async {
    final data = await _get(wikidataApi, {
      'action': 'wbgetclaims',
      'entity': qid,
      'property': property,
      'format': 'json',
    });
    final claims = data['claims'];
    if (claims is! Map) return null;
    final list = claims[property];
    if (list is! List) return null;
    for (final claim in list) {
      if (claim is! Map || claim['rank'] == 'deprecated') continue;
      final value =
          ((claim['mainsnak'] as Map?)?['datavalue'] as Map?)?['value'];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  Future<BusinessImage?> _imageInfo(
    String title,
    BusinessImageKind kind,
  ) async {
    final data = await _get(commonsApi, {
      'action': 'query',
      'titles': 'File:$title',
      'prop': 'imageinfo',
      'iiprop': 'url|mime|extmetadata',
      'iiurlwidth': '$thumbnailWidth',
      'iiextmetadatafilter': 'LicenseShortName|LicenseUrl|Artist',
      'format': 'json',
      'formatversion': '2',
    });
    return parseCommonsImageInfo(data, kind: kind);
  }

  Future<Map<String, Object?>> _get(
    String url,
    Map<String, String> query,
  ) async {
    await _acquire();
    try {
      requestCount++;
      final response = await _dio.get<Object?>(url, queryParameters: query);
      final data = response.data;
      if (data is! Map) throw const FormatException('Not a JSON object');
      return data.cast<String, Object?>();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_running < maxConcurrent) {
      _running++;
      return;
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    await waiter.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _running--;
    }
  }
}

/// Parses a Commons `imageinfo` response (formatversion=2). Returns null
/// unless there is a thumbnail, a source page and a license to credit.
@visibleForTesting
BusinessImage? parseCommonsImageInfo(
  Map<String, Object?> data, {
  required BusinessImageKind kind,
}) {
  final pages = (data['query'] as Map?)?['pages'];
  if (pages is! List || pages.isEmpty) return null;
  final page = pages.first;
  if (page is! Map || page['missing'] == true) return null;
  final infos = page['imageinfo'];
  if (infos is! List || infos.isEmpty || infos.first is! Map) return null;
  final info = infos.first as Map;

  final mime = info['mime'];
  if (mime is! String || !mime.startsWith('image/')) return null;
  final thumb = info['thumburl'];
  final pageUrl = info['descriptionurl'];
  if (thumb is! String || !_isWikimediaUrl(thumb)) return null;
  if (pageUrl is! String || !_isWikimediaUrl(pageUrl)) return null;

  final meta = info['extmetadata'];
  String? metaValue(String key) {
    final entry = meta is Map ? meta[key] : null;
    final value = entry is Map ? entry['value'] : null;
    if (value is! String) return null;
    final text = stripHtml(value);
    return text.isEmpty ? null : text;
  }

  final license = metaValue('LicenseShortName');
  if (license == null) return null;
  final title = page['title'];
  return BusinessImage(
    kind: kind,
    thumbnailUrl: thumb,
    sourcePageUrl: pageUrl,
    fileTitle: title is String ? title : 'Wikimedia Commons file',
    license: _clip(license, 60),
    author: switch (metaValue('Artist')) {
      final a? => _clip(a, 80),
      null => null,
    },
    licenseUrl: metaValue('LicenseUrl'),
  );
}

bool _isWikimediaUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'https' &&
      (uri.host == 'upload.wikimedia.org' ||
          uri.host == 'commons.wikimedia.org');
}

/// Commons metadata values are HTML snippets; keep plain text only.
@visibleForTesting
String stripHtml(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#039;', "'")
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _clip(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max - 1).trimRight()}…';

String describeImageError(Object e) => e is DioException
    ? 'HTTP ${e.response?.statusCode ?? e.type.name}'
    : e.runtimeType.toString();

/// Wikimedia asks API clients for a descriptive User-Agent with contact
/// details; the same identity as the Overpass client.
Dio createWikimediaDio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'User-Agent': OverpassConfig.userAgent},
    responseType: ResponseType.json,
  ),
);

final businessImageRepositoryProvider = Provider<BusinessImageRepository>(
  (ref) => BusinessImageRepository(),
);

/// One resolved image per set of references. Lives as long as a widget
/// watches it; the repository's own cache survives longer.
final businessImageProvider = FutureProvider.autoDispose
    .family<BusinessImage?, BusinessImageRefs>(
      (ref, refs) => ref.watch(businessImageRepositoryProvider).resolve(refs),
    );
